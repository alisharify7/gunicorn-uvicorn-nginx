#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd "${SCRIPT_DIR}/.." && pwd)
VARIANT=${1:-}
BASE_IMAGE=${2:-}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'PASS: %s\n' "$*"
}

container_running() {
    docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null | grep -qx true
}

show_logs() {
    printf '%s\n' "--- logs: $1 ---" >&2
    docker logs "$1" >&2 || :
}

wait_for_http() {
    name=$1
    url=$2
    attempts=${3:-60}
    count=0

    while [ "$count" -lt "$attempts" ]; do
        if curl --fail --silent --show-error --max-time 2 "$url" >/dev/null 2>&1; then
            return 0
        fi
        if ! container_running "$name"; then
            show_logs "$name"
            fail "${name} exited before ${url} became ready"
        fi
        count=$((count + 1))
        sleep 1
    done

    show_logs "$name"
    fail "timed out waiting for ${url}"
}

stop_cleanly() {
    name=$1
    docker stop --timeout 10 "$name" >/dev/null
    exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$name")
    test "$exit_code" -eq 0 || fail "${name} stopped with exit code ${exit_code}"
}

case "$VARIANT" in
    main) examples='fastapi_app static_files' ;;
    alpine) examples='simple config_gunicorn config_nginx flask_app' ;;
    *) fail "usage: $0 {main|alpine} BASE_IMAGE" ;;
esac

test -n "$BASE_IMAGE" || fail "usage: $0 {main|alpine} BASE_IMAGE"
command -v docker >/dev/null 2>&1 || fail 'docker is required'
command -v curl >/dev/null 2>&1 || fail 'curl is required'

suffix="${VARIANT}-$$"
containers=

cleanup() {
    for container in $containers; do
        docker rm -f "$container" >/dev/null 2>&1 || :
    done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

for example in $examples; do
    tag="gunicorn-uvicorn-nginx:example-${example}-${suffix}"
    name="gunicorn-uvicorn-nginx-example-${example}-${suffix}"
    containers="${containers} ${name}"

    docker build \
        --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
        --tag "$tag" \
        "${REPO_ROOT}/example/${example}"

    docker run --detach --name "$name" --publish 127.0.0.1::80 "$tag" >/dev/null
    published=$(docker port "$name" 80/tcp | sed -n '1p')
    test -n "$published" || fail "Docker did not publish ${name} port 80"
    port=${published##*:}
    root_url="http://127.0.0.1:${port}"
    wait_for_http "$name" "${root_url}/"

    case "$example" in
        simple)
            response=$(curl --fail --silent --show-error "${root_url}/")
            printf '%s' "$response" | grep -q 'World from gunicorn-uvicorn-nginx' || \
                fail "unexpected simple response: ${response}"
            ;;
        config_gunicorn)
            response=$(curl --fail --silent --show-error "${root_url}/")
            printf '%s' "$response" | grep -q 'World from gunicorn-uvicorn-nginx' || \
                fail "unexpected config_gunicorn response: ${response}"
            docker logs "$name" 2>&1 | grep -q 'bind=127.0.0.1:6565' || \
                fail 'config_gunicorn did not use its configured internal port'
            ;;
        config_nginx)
            headers=$(curl --fail --silent --show-error --dump-header - --output /dev/null \
                "${root_url}/")
            printf '%s\n' "$headers" | tr -d '\r' | \
                grep -qi '^X-Example-Config: enabled$' || \
                fail 'config_nginx did not add its configured response header'
            ;;
        flask_app)
            response=$(curl --fail --silent --show-error "${root_url}/health")
            printf '%s' "$response" | grep -q '"status":"healthy"' || \
                fail "unexpected Flask health response: ${response}"
            ;;
        fastapi_app)
            response=$(curl --fail --silent --show-error "${root_url}/health")
            printf '%s' "$response" | grep -q '"status":"healthy"' || \
                fail "unexpected FastAPI health response: ${response}"
            curl --fail-with-body --silent --show-error \
                --request POST \
                --header 'Content-Type: application/json' \
                --data '{"id":1,"name":"Smoke Test","email":"smoke@example.com"}' \
                "${root_url}/users" >/dev/null
            response=$(curl --fail --silent --show-error "${root_url}/users/1")
            printf '%s' "$response" | grep -q '"email":"smoke@example.com"' || \
                fail "FastAPI user was not persisted by the example: ${response}"
            ;;
        static_files)
            headers=$(curl --fail --silent --show-error --dump-header - --output /dev/null \
                "${root_url}/")
            printf '%s\n' "$headers" | tr -d '\r' | grep -qi '^Content-Type: text/html' || \
                fail 'static_files root did not return an HTML content type'
            response=$(curl --fail --silent --show-error "${root_url}/static/index.html")
            printf '%s' "$response" | grep -q 'FastAPI + Static Files Example' || \
                fail 'static_files did not expose the mounted static directory'
            ;;
    esac

    stop_cleanly "$name"
    pass "${example} build and runtime smoke"
done

pass "all ${VARIANT} example smoke tests"
