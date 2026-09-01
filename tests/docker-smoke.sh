#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd "${SCRIPT_DIR}/.." && pwd)
VARIANT=${1:-}
IMAGE=${2:-}

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
        if response=$(curl --fail --silent --show-error --max-time 2 "$url" 2>/dev/null); then
            test -n "$response" || fail "empty HTTP response from ${url}"
            if printf '%s' "$response" | python3 -c \
                'import json, sys; assert isinstance(json.load(sys.stdin), dict)'; then
                return 0
            fi
        fi

        if ! container_running "$name"; then
            show_logs "$name"
            fail "${name} exited before becoming ready"
        fi

        count=$((count + 1))
        sleep 1
    done

    show_logs "$name"
    fail "timed out waiting for ${url}"
}

wait_for_health() {
    name=$1
    attempts=${2:-45}
    count=0

    while [ "$count" -lt "$attempts" ]; do
        health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$name")
        case "$health" in
            healthy) return 0 ;;
            unhealthy)
                show_logs "$name"
                fail "${name} reported an unhealthy Docker health check"
                ;;
            missing) fail "${name} does not have a Docker health check" ;;
        esac

        if ! container_running "$name"; then
            show_logs "$name"
            fail "${name} exited before its Docker health check passed"
        fi

        count=$((count + 1))
        sleep 1
    done

    show_logs "$name"
    fail "timed out waiting for ${name} to become healthy"
}

wait_for_container_http() {
    name=$1
    attempts=${2:-60}
    count=0

    while [ "$count" -lt "$attempts" ]; do
        if docker exec "$name" python3 -c \
            "import json, urllib.request; json.load(urllib.request.urlopen('http://127.0.0.1/', timeout=2))" \
            >/dev/null 2>&1; then
            return 0
        fi

        if ! container_running "$name"; then
            show_logs "$name"
            fail "${name} exited before becoming ready without a network"
        fi

        count=$((count + 1))
        sleep 1
    done

    show_logs "$name"
    fail "timed out waiting for HTTP inside ${name}"
}

stop_cleanly() {
    name=$1

    docker stop --timeout 10 "$name" >/dev/null
    status=$(docker inspect --format '{{.State.Status}}' "$name")
    exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$name")

    test "$status" = exited || fail "${name} did not stop (state: ${status})"
    test "$exit_code" -ne 137 || fail "${name} required SIGKILL to stop"
    test "$exit_code" -eq 0 || fail "${name} stopped with exit code ${exit_code}"
}

wait_for_exit() {
    name=$1
    attempts=${2:-15}
    count=0

    while [ "$count" -lt "$attempts" ]; do
        if ! container_running "$name"; then
            return 0
        fi
        count=$((count + 1))
        sleep 1
    done

    show_logs "$name"
    fail "${name} did not exit after a supervised process stopped"
}

signal_cleanly() {
    name=$1
    signal_name=$2

    docker kill --signal "$signal_name" "$name" >/dev/null
    wait_for_exit "$name"
    exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$name")
    test "$exit_code" -eq 0 || \
        fail "${name} stopped after ${signal_name} with exit code ${exit_code}"
}

case "$VARIANT" in
    main|alpine) ;;
    *) fail "usage: $0 {main|alpine} [IMAGE]" ;;
esac

command -v docker >/dev/null 2>&1 || fail 'docker is required'
command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required for the WebSocket smoke test'

if [ -z "$IMAGE" ]; then
    IMAGE="gunicorn-uvicorn-nginx:smoke-${VARIANT}"
    docker build --tag "$IMAGE" "${REPO_ROOT}/docker/${VARIANT}"
fi

suffix="${VARIANT}-$$"
http_container="gunicorn-uvicorn-nginx-http-${suffix}"
offline_container="gunicorn-uvicorn-nginx-offline-${suffix}"
websocket_container="gunicorn-uvicorn-nginx-websocket-${suffix}"
wsgi_container="gunicorn-uvicorn-nginx-wsgi-${suffix}"
nginx_failure_container="gunicorn-uvicorn-nginx-nginx-failure-${suffix}"
gunicorn_failure_container="gunicorn-uvicorn-nginx-gunicorn-failure-${suffix}"
args_container="gunicorn-uvicorn-nginx-args-${suffix}"
legacy_container="gunicorn-uvicorn-nginx-legacy-${suffix}"
server_snippet_dir=$(mktemp -d "${TMPDIR:-/tmp}/gunicorn-uvicorn-nginx-server-d.XXXXXX")
invalid_output=$(mktemp "${TMPDIR:-/tmp}/gunicorn-uvicorn-nginx-invalid.XXXXXX")

cleanup() {
    docker rm -f "$http_container" "$offline_container" "$websocket_container" \
        "$wsgi_container" "$nginx_failure_container" "$gunicorn_failure_container" \
        "$args_container" "$legacy_container" \
        >/dev/null 2>&1 || :
    if [ -d "$server_snippet_dir" ]; then
        rm -rf "$server_snippet_dir"
    fi
    rm -f "$invalid_output"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

cp "${SCRIPT_DIR}/fixtures/smoke-header.conf" "${server_snippet_dir}/smoke-header.conf"

docker run --detach \
    --name "$http_container" \
    --publish 127.0.0.1::80 \
    --health-interval 1s \
    --health-start-period 1s \
    "$IMAGE" >/dev/null
published=$(docker port "$http_container" 80/tcp | sed -n '1p')
test -n "$published" || fail "Docker did not publish ${http_container} port 80"
http_port=${published##*:}
wait_for_http "$http_container" "http://127.0.0.1:${http_port}/"
fallback_response=$(curl --fail --silent --show-error "http://127.0.0.1:${http_port}/")
printf '%s' "$fallback_response" | python3 -c \
    'import json, sys; assert json.load(sys.stdin) == {"message": "gunicorn-uvicorn-nginx is running"}' || \
    fail "unexpected fallback response: ${fallback_response}"
fallback_headers=$(curl --fail --silent --show-error --dump-header - --output /dev/null \
    "http://127.0.0.1:${http_port}/")
printf '%s\n' "$fallback_headers" | tr -d '\r' | \
    grep -qi '^Content-Type: application/json$' || \
    fail 'fallback response did not use application/json'
wait_for_health "$http_container"
pass "${VARIANT} root HTTP response"
pass "${VARIANT} Docker health check"
docker kill --signal HUP "$http_container" >/dev/null
wait_for_http "$http_container" "http://127.0.0.1:${http_port}/"
container_running "$http_container" || fail "${http_container} exited during HUP reload"
pass "${VARIANT} reloads after HUP"
stop_cleanly "$http_container"
pass "${VARIANT} graceful container stop"

docker run --detach --name "$offline_container" --network none "$IMAGE" >/dev/null
wait_for_container_http "$offline_container"
pass "${VARIANT} starts and serves HTTP without network access"
signal_cleanly "$offline_container" QUIT
pass "${VARIANT} shuts down cleanly after QUIT"

docker run --detach --name "$nginx_failure_container" "$IMAGE" >/dev/null
wait_for_container_http "$nginx_failure_container"
docker exec "$nginx_failure_container" nginx -s quit >/dev/null
wait_for_exit "$nginx_failure_container"
failure_exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$nginx_failure_container")
test "$failure_exit_code" -ne 0 || fail \
    "${nginx_failure_container} reported success after Nginx stopped unexpectedly"
test "$failure_exit_code" -ne 137 || fail \
    "${nginx_failure_container} required SIGKILL after Nginx stopped unexpectedly"
pass "${VARIANT} supervises an unexpected Nginx exit"

docker run --detach --name "$gunicorn_failure_container" "$IMAGE" >/dev/null
wait_for_container_http "$gunicorn_failure_container"
docker exec "$gunicorn_failure_container" sh -c '
    for pid in $(cat /proc/1/task/1/children); do
        command=$(tr "\000" " " < "/proc/${pid}/cmdline")
        case "$command" in
            *gunicorn*) kill -TERM "$pid"; exit 0 ;;
        esac
    done
    exit 1
' >/dev/null
wait_for_exit "$gunicorn_failure_container"
failure_exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$gunicorn_failure_container")
test "$failure_exit_code" -ne 0 || fail \
    "${gunicorn_failure_container} reported success after Gunicorn stopped unexpectedly"
test "$failure_exit_code" -ne 137 || fail \
    "${gunicorn_failure_container} required SIGKILL after Gunicorn stopped unexpectedly"
pass "${VARIANT} supervises an unexpected Gunicorn exit"

invalid_status=0
docker run --rm --env GUNICORN_WORKERS=0 "$IMAGE" >"$invalid_output" 2>&1 || invalid_status=$?
test "$invalid_status" -eq 64 || fail \
    "invalid worker count exited with ${invalid_status}, expected 64"
grep -q 'GUNICORN_WORKERS must be greater than zero' "$invalid_output" || \
    fail 'invalid worker count did not produce the expected validation error'
pass "${VARIANT} rejects invalid generated Gunicorn settings"

docker run --detach \
    --name "$args_container" \
    --publish 127.0.0.1::80 \
    --env 'GUNICORN_CMD_ARGS=--worker-class uvicorn_worker.UvicornWorker --bind 127.0.0.1:8123 --workers 1 --timeout 30' \
    --env NGINX_UPSTREAM_PORT=8123 \
    "$IMAGE" >/dev/null
published=$(docker port "$args_container" 80/tcp | sed -n '1p')
test -n "$published" || fail "Docker did not publish ${args_container} port 80"
args_port=${published##*:}
wait_for_http "$args_container" "http://127.0.0.1:${args_port}/"
stop_cleanly "$args_container"
pass "${VARIANT} accepts aligned custom GUNICORN_CMD_ARGS"

docker run --detach \
    --name "$wsgi_container" \
    --publish 127.0.0.1::80 \
    --env APP_MODULE=wsgi_app:app \
    --env GUNICORN_WORKER_CLASS=gthread \
    --env GUNICORN_THREADS=2 \
    --mount "type=bind,src=${SCRIPT_DIR}/fixtures/wsgi_app.py,dst=/app/wsgi_app.py,readonly" \
    --mount "type=bind,src=${SCRIPT_DIR}/fixtures/http-map.conf,dst=/etc/nginx/conf.d/smoke-map.conf,readonly" \
    --mount "type=bind,src=${server_snippet_dir},dst=/etc/nginx/server.d" \
    "$IMAGE" >/dev/null
published=$(docker port "$wsgi_container" 80/tcp | sed -n '1p')
test -n "$published" || fail "Docker did not publish ${wsgi_container} port 80"
wsgi_port=${published##*:}
wait_for_http "$wsgi_container" "http://127.0.0.1:${wsgi_port}/"
wsgi_response=$(curl --fail --silent --show-error "http://127.0.0.1:${wsgi_port}/")
printf '%s' "$wsgi_response" | grep -q '"interface":"wsgi"' || \
    fail "gthread worker did not serve the WSGI fixture: ${wsgi_response}"
well_known_response=$(curl --fail --silent --show-error \
    "http://127.0.0.1:${wsgi_port}/.well-known/openid-configuration")
printf '%s' "$well_known_response" | grep -q '"interface":"wsgi"' || \
    fail "Nginx intercepted the application-owned /.well-known route: ${well_known_response}"
wsgi_headers=$(curl --fail --silent --show-error --dump-header - --output /dev/null \
    "http://127.0.0.1:${wsgi_port}/")
printf '%s\n' "$wsgi_headers" | tr -d '\r' | \
    grep -qi '^X-Gunicorn-Uvicorn-Nginx-Smoke: passed$' || \
    fail 'mounted /etc/nginx/server.d snippet did not add its response header'
printf '%s\n' "$wsgi_headers" | tr -d '\r' | \
    grep -qi '^X-Gunicorn-Uvicorn-Nginx-Scope: http-scope$' || \
    fail 'mounted /etc/nginx/conf.d map was not available to the server.d snippet'
pass "${VARIANT} WSGI gthread worker and both Nginx extension scopes"
stop_cleanly "$wsgi_container"

docker run --detach \
    --name "$legacy_container" \
    --publish 127.0.0.1::80 \
    --mount "type=bind,src=${SCRIPT_DIR}/fixtures/legacy-custom.conf,dst=/app/custom.conf,readonly" \
    "$IMAGE" >/dev/null
published=$(docker port "$legacy_container" 80/tcp | sed -n '1p')
test -n "$published" || fail "Docker did not publish ${legacy_container} port 80"
legacy_port=${published##*:}
wait_for_http "$legacy_container" "http://127.0.0.1:${legacy_port}/"
legacy_headers=$(curl --fail --silent --show-error --dump-header - --output /dev/null \
    "http://127.0.0.1:${legacy_port}/")
printf '%s\n' "$legacy_headers" | tr -d '\r' | \
    grep -qi '^X-Legacy-Custom-Conf: passed$' || \
    fail 'legacy /app/custom.conf did not replace the image template'
docker logs "$legacy_container" 2>&1 | grep -q '/app/custom.conf is deprecated' || \
    fail 'legacy /app/custom.conf did not produce its deprecation warning'
stop_cleanly "$legacy_container"
pass "${VARIANT} legacy /app/custom.conf compatibility"

docker run --rm --entrypoint python3 "$IMAGE" -c \
    "import importlib.util; assert importlib.util.find_spec('websockets') or importlib.util.find_spec('wsproto')" \
    >/dev/null 2>&1 || \
    fail "${VARIANT} image lacks the pinned WebSocket protocol backend"

docker run --detach \
    --name "$websocket_container" \
    --publish 127.0.0.1::80 \
    --mount "type=bind,src=${SCRIPT_DIR}/fixtures/websocket_app.py,dst=/app/main.py,readonly" \
    "$IMAGE" >/dev/null
published=$(docker port "$websocket_container" 80/tcp | sed -n '1p')
test -n "$published" || fail "Docker did not publish ${websocket_container} port 80"
websocket_port=${published##*:}
wait_for_http "$websocket_container" "http://127.0.0.1:${websocket_port}/"
python3 "${SCRIPT_DIR}/websocket_client.py" 127.0.0.1 "$websocket_port"
stop_cleanly "$websocket_container"
pass "${VARIANT} WebSocket lifecycle"

pass "all ${VARIANT} Docker smoke tests"
