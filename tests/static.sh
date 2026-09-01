#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd "${SCRIPT_DIR}/.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'PASS: %s\n' "$*"
}

assert_contains() {
    pattern=$1
    file=$2
    description=$3

    if ! grep -Eq "$pattern" "$file"; then
        fail "${description}: ${file}"
    fi
}

assert_not_contains() {
    pattern=$1
    file=$2
    description=$3

    if grep -Eq "$pattern" "$file"; then
        fail "${description}: ${file}"
    fi
}

cd "$REPO_ROOT"

for shell_file in docker/build.sh tests/*.sh; do
    sh -n "$shell_file" || fail "invalid POSIX shell syntax in ${shell_file}"
done
pass 'repository shell syntax'

for variant in main alpine; do
    context="docker/${variant}"

    for required in Dockerfile start.sh nginx.conf custom.conf main.py requirements.txt; do
        test -f "${context}/${required}" || fail "missing ${context}/${required}"
    done

    sh -n "${context}/start.sh" || fail "invalid POSIX shell syntax in ${context}/start.sh"

    assert_not_contains \
        '(^|[[:space:];&|])(pip3?|python3[[:space:]]+-m[[:space:]]+pip)[[:space:]]+install([[:space:]]|$)' \
        "${context}/start.sh" \
        'container startup must not install packages'

    assert_contains \
        '^EXPOSE[[:space:]]+80([[:space:]]|$)' \
        "${context}/Dockerfile" \
        'image must expose its public HTTP port'

    if ! grep -Eq 'APP_MODULE.*main:app|main:app.*APP_MODULE' \
        "${context}/Dockerfile" "${context}/start.sh" >/dev/null; then
        fail "image must declare main:app as the default application: ${context}"
    fi

    assert_contains \
        '^HEALTHCHECK([[:space:]]|$)' \
        "${context}/Dockerfile" \
        'image must declare a health check'

    assert_contains \
        '\$\{NGINX_UPSTREAM_ADDRESS\}' \
        "${context}/custom.conf" \
        'Nginx template must retain the upstream-address token'

    assert_contains \
        '\$\{NGINX_UPSTREAM_PORT\}' \
        "${context}/custom.conf" \
        'Nginx template must retain the upstream-port token'

    assert_not_contains \
        '^[[:space:]]*server[[:space:]]*\{' \
        "${context}/custom.conf" \
        'custom.conf is included inside the existing server block'

    assert_not_contains \
        'location[[:space:]]+\^~[[:space:]]+[/][.]well-known' \
        "${context}/custom.conf" \
        'Nginx must not intercept application-owned /.well-known routes'

    pass "${variant} static contract"
done

for shared in start.sh nginx.conf custom.conf main.py requirements.txt; do
    if ! cmp -s "docker/main/${shared}" "docker/alpine/${shared}"; then
        diff -u "docker/main/${shared}" "docker/alpine/${shared}" >&2 || :
        fail "shared runtime file differs between image variants: ${shared}"
    fi
done
pass 'Debian and Alpine shared-file parity'

if command -v python3 >/dev/null 2>&1; then
    for python_file in \
        docker/*/main.py \
        example/*/main.py \
        tests/websocket_client.py \
        tests/fixtures/websocket_app.py \
        tests/fixtures/wsgi_app.py; do
        python3 -c \
            'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), filename=sys.argv[1])' \
            "$python_file"
    done
    pass 'Python fixture syntax'
else
    fail 'python3 is required to validate the WebSocket smoke-test fixture'
fi

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck --shell=sh docker/build.sh docker/main/start.sh docker/alpine/start.sh tests/*.sh
    pass 'ShellCheck'
elif [ "${REQUIRE_SHELLCHECK:-0}" = 1 ]; then
    fail 'shellcheck is required but is not installed'
else
    printf 'SKIP: ShellCheck is not installed\n'
fi

for executable_file in \
    docker/build.sh \
    docker/main/start.sh \
    docker/alpine/start.sh \
    tests/static.sh \
    tests/docker-smoke.sh \
    tests/examples-smoke.sh; do
    executable_mode=$(git ls-files --stage -- "$executable_file" | awk 'NR == 1 { print $1 }')
    if [ "$executable_mode" != 100755 ]; then
        fail "executable script must be committed with mode 100755: ${executable_file}"
    fi
done
pass 'repository executable modes'

assert_contains '^\*\.md$' .gitignore 'all Markdown files must be ignored by default'
assert_contains '^!/README\.md$' .gitignore 'the root README must remain publishable'
assert_contains '^!/README-DEV\.md$' .gitignore 'the maintainer guide must remain publishable'

for public_markdown in README.md README-DEV.md; do
    test -f "$public_markdown" || fail "missing public document: ${public_markdown}"
    if git check-ignore --no-index -q -- "$public_markdown"; then
        fail "public document is ignored: ${public_markdown}"
    fi

    markdown_links=$(grep -Eo '\]\([^)]*\.md([#?][^)]*)?\)' "$public_markdown" || :)
    if [ -n "$markdown_links" ]; then
        invalid_markdown_links=$(
            printf '%s\n' "$markdown_links" |
                grep -Ev '^\]\((\./)?README(-DEV)?\.md([#?][^)]*)?\)$' || :
        )
        if [ -n "$invalid_markdown_links" ]; then
            printf 'Invalid Markdown links in %s:\n%s\n' \
                "$public_markdown" "$invalid_markdown_links" >&2
            fail "public document links to an ignored Markdown file: ${public_markdown}"
        fi
    fi
done

for local_markdown in AGENTS.md MEMORY.md PROJECT_MAP.md example/README.md; do
    if [ -e "$local_markdown" ] && ! git check-ignore --no-index -q -- "$local_markdown"; then
        fail "local Markdown note must remain ignored: ${local_markdown}"
    fi
done

expected_public_markdown=$(printf '%s\n' README-DEV.md README.md)
actual_public_markdown=$(
    git ls-files --cached --others --exclude-standard -- '*.md' |
        LC_ALL=C sort
)
if [ "$actual_public_markdown" != "$expected_public_markdown" ]; then
    printf 'Public Markdown files:\n%s\n' "$actual_public_markdown" >&2
    fail 'only README.md and README-DEV.md may be published'
fi

assert_contains \
    '\]\((\./)?README-DEV\.md([#?][^)]*)?\)' \
    README.md \
    'README.md must link to the maintainer guide'
assert_contains \
    '\]\((\./)?README\.md([#?][^)]*)?\)' \
    README-DEV.md \
    'README-DEV.md must link back to the user guide'
pass 'public Markdown policy'

pass 'all static checks'
