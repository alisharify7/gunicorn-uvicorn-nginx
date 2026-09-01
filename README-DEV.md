# Maintainer Guide

This guide covers development, testing, releases, and ongoing maintenance of the
Gunicorn + Uvicorn + Nginx base images. For consumer usage, start with the
[user guide](README.md).

## Repository contract

The repository builds two variants of the same runtime:

```text
client -> Nginx :80 -> Gunicorn 127.0.0.1:8000 -> main:app
```

| Variant | Build context | Upstream base | Local test tag |
| --- | --- | --- | --- |
| Debian | `docker/main/` | `nginx:1.30.4-trixie` | `gunicorn-uvicorn-nginx:main-test` |
| Alpine | `docker/alpine/` | `nginx:1.30.4-alpine3.24` | `gunicorn-uvicorn-nginx:alpine-test` |

The Dockerfiles, `start.sh`, `nginx.conf`, and `custom.conf` are the runtime source of
truth. Keep these shared files byte-identical between variants:

```text
start.sh
nginx.conf
custom.conf
main.py
requirements.txt
```

Only distribution-specific installation belongs in the Dockerfiles. The bundled
`main.py` must remain a dependency-free ASGI smoke application; application
dependencies belong in consumer images.

## Repository layout

```text
docker/main/                 Debian image context
docker/alpine/               Alpine image context
docker/build.sh              Buildx Bake wrapper; always loads local images
docker-bake.hcl              Build targets and local tags
example/                     Consumer image examples
tests/static.sh              Fast repository contract checks
tests/docker-smoke.sh        Base-image runtime and lifecycle tests
tests/examples-smoke.sh      Build-and-run tests for every example
tests/fixtures/              ASGI, WSGI, WebSocket, and Nginx fixtures
.github/workflows/ci.yml     Pull-request and push validation
.hadolint.yaml               Dockerfile lint configuration
README.md                    Public consumer guide
README-DEV.md                Public maintainer guide
```

Other Markdown files are local notes and are intentionally ignored by Git.

## Prerequisites

Fast checks require:

- POSIX `sh`
- Python 3
- ShellCheck when running the CI-equivalent static check

Build and smoke tests additionally require:

- Docker Engine or Docker Desktop with a running daemon
- Docker Buildx with Bake support
- `curl`
- network access while pulling base images or installing Python packages

## Development workflow

Start with the fast checks:

```sh
./tests/static.sh
docker buildx bake --print
```

Build both images and load them into the local Docker daemon:

```sh
./docker/build.sh
```

The helper runs `docker buildx bake --load`; `docker-bake.hcl` also enables fresh base
pulls. Build a focused target during iteration:

```sh
./docker/build.sh main
./docker/build.sh alpine
```

Direct builds are also supported:

```sh
docker build --pull -t gunicorn-uvicorn-nginx:main-test docker/main
docker build --pull -t gunicorn-uvicorn-nginx:alpine-test docker/alpine
```

## Full validation

Run the CI-equivalent static check, build both images, and exercise every runtime and
example:

```sh
REQUIRE_SHELLCHECK=1 ./tests/static.sh
docker buildx bake --print
./docker/build.sh

for variant in main alpine; do
  test_image="gunicorn-uvicorn-nginx:${variant}-test"
  ./tests/docker-smoke.sh "$variant" "$test_image"
  ./tests/examples-smoke.sh "$variant" "$test_image"
done
```

Run focused suites when changing only one variant:

```sh
./tests/docker-smoke.sh main gunicorn-uvicorn-nginx:main-test
./tests/docker-smoke.sh alpine gunicorn-uvicorn-nginx:alpine-test

./tests/examples-smoke.sh main gunicorn-uvicorn-nginx:main-test
./tests/examples-smoke.sh alpine gunicorn-uvicorn-nginx:alpine-test
```

Lint Dockerfiles locally when Hadolint is installed:

```sh
hadolint --config .hadolint.yaml \
  docker/main/Dockerfile \
  docker/alpine/Dockerfile
```

### What the tests cover

The static suite checks:

- POSIX shell and Python syntax
- required runtime files and Dockerfile contracts
- byte parity of shared Debian and Alpine runtime files
- the no-package-install-at-startup rule
- Nginx template tokens and `/.well-known/` routing
- executable script modes and public Markdown policy
- ShellCheck when installed, or always when `REQUIRE_SHELLCHECK=1`

The base-image smoke suite checks:

- exact fallback HTTP response and content type
- Docker listener health
- startup without network access
- graceful `TERM` and `QUIT` handling, plus `HUP` reloads
- symmetric Gunicorn and Nginx failure supervision
- rejection of an invalid worker count
- custom `GUNICORN_CMD_ARGS` and aligned upstream ports
- ASGI, WSGI `gthread`, and WebSocket upgrade/echo/close behavior
- `conf.d` HTTP scope and `server.d` server scope
- legacy `/app/custom.conf` behavior
- application-owned `/.well-known/` routes

The example suite builds and runs all six consumer examples against the freshly built
local image for their variant.

Passing static checks does not prove an image builds. Passing a Docker build does not
prove lifecycle or proxy behavior. Report these validation levels separately.

## Runtime startup sequence

`start.sh` is PID 1 and performs this sequence:

1. Resolve defaults and validate application, address, port, worker, and timeout
   settings.
2. Generate Gunicorn arguments unless `GUNICORN_CMD_ARGS` is non-empty.
3. Render the Nginx server template into `/etc/nginx/server.d/default.conf`.
4. Run `nginx -t`.
5. Start and supervise Gunicorn and Nginx.
6. Translate shutdown/reload signals and reap both children.

An unexpected exit from either child stops its peer and exits non-zero. Keep shell
code POSIX-compatible and quote expansions unless splitting is deliberately delegated
to Gunicorn.

## Nginx maintenance rules

- `/etc/nginx/conf.d/*.conf` is included at `http` scope.
- `/etc/nginx/server.d/*.conf` is included inside the built-in server.
- The owned proxy template is `/opt/gunicorn-uvicorn-nginx/custom.conf`.
- Readable `/app/custom.conf` has legacy precedence and emits a deprecation warning.
- Preserve literal `${NGINX_UPSTREAM_ADDRESS}` and `${NGINX_UPSTREAM_PORT}` tokens.
- Do not add a `server {}` wrapper to the image-owned template.
- Do not use `default.conf` for a consumer server snippet; startup overwrites it.
- Do not make the entire `server.d` directory read-only.
- Keep `/.well-known/` available to the application unless a more-specific location
  deliberately handles it.
- Do not trust direct client forwarding headers. Any trusted-proxy policy must define
  which proxy addresses are trusted and must have a regression test.

Startup renders the proxy template only once. `HUP` reloads the running services but
does not render a changed template; restart the container after template changes.

For every Nginx behavior change, keep both variants aligned, ensure startup passes
`nginx -t`, and add a behavioral smoke regression where practical.

## Making changes

### Shared runtime change

1. Apply the same change to both variant directories.
2. Run `./tests/static.sh` immediately; parity failures should be fixed before broader
   testing.
3. Build and smoke-test both variants.
4. Update the consumer guide for any observable behavior change.

### Distribution-specific change

Keep package-manager and base-image differences inside the relevant Dockerfile. Build
and smoke-test the changed variant, then run the parity/static checks to confirm shared
files did not drift.

### Dependency update

Server dependencies are pinned in both `requirements.txt` files. Update them together,
keep the files byte-identical, then rebuild both variants with fresh pulls and run the
full smoke matrix. Do not add FastAPI, Flask, Django, or application dependencies to
the base image.

### Configuration change

Preserve these defaults unless the change is deliberately breaking:

| Setting | Default |
| --- | --- |
| `APP_MODULE` | `main:app` |
| `GUNICORN_WORKER_CLASS` | `uvicorn_worker.UvicornWorker` |
| `GUNICORN_WORKERS` | `2` |
| `GUNICORN_THREADS` | `4` |
| `GUNICORN_TIMEOUT` | `120` |
| `GUNICORN_BIND_ADDRESS` | `127.0.0.1` |
| `GUNICORN_BIND_PORT` | `8000` |
| `NGINX_UPSTREAM_ADDRESS` | `127.0.0.1` |
| `NGINX_UPSTREAM_PORT` | value of `GUNICORN_BIND_PORT` when unset |

`GUNICORN_THREADS` is generated only for the exact `gthread` worker. A non-empty
`GUNICORN_CMD_ARGS` replaces all generated flags but never replaces `APP_MODULE`.

## CI

CI runs on pushes, pull requests, and manual dispatches. It:

1. Runs static checks with ShellCheck required.
2. Parses the Bake definition.
3. Lints both Dockerfiles with Hadolint.
4. Builds each image variant independently.
5. Runs the matching base-image and example smoke suites.

Third-party actions are pinned to commit SHAs. When updating one, verify the upstream
release, change the SHA and version comment together, and let the entire CI matrix run.

## Publishing a release

There is no automatic publish workflow. Publishing is a deliberate maintainer action.
Existing Docker Hub aliases can lag behind the source, so never announce the new
runtime contract until the pushed images have been verified.

As verified on 2026-09-01, Docker Hub still contains the legacy `latest`, `1.0.0`,
`alpine-latest`, and `alpine-1.0.0` images. There is no `alpine` alias. Refresh and
verify the moving aliases as part of the next release.

The existing tag convention is:

| Variant | Moving tag | Versioned tag example |
| --- | --- | --- |
| Debian | `latest` | `2.0.0` |
| Alpine | `alpine-latest` | `alpine-2.0.0` |

Before publishing:

1. Run the full validation matrix.
2. Review `git diff --check` and confirm the intended commit is on `main`.
3. Choose a release version and update user-facing version references if needed.
4. Log in to Docker Hub without placing credentials in the repository.

Build and push the current builder architecture:

```sh
IMAGE_REPOSITORY=alisharify7/gunicorn-uvicorn-nginx
RELEASE_VERSION=2.0.0

docker login

docker buildx build --pull --push \
  --tag "${IMAGE_REPOSITORY}:${RELEASE_VERSION}" \
  --tag "${IMAGE_REPOSITORY}:latest" \
  docker/main

docker buildx build --pull --push \
  --tag "${IMAGE_REPOSITORY}:alpine-${RELEASE_VERSION}" \
  --tag "${IMAGE_REPOSITORY}:alpine-latest" \
  docker/alpine
```

The repository does not currently claim a tested multi-architecture release matrix.
Do not add `--platform` targets until every advertised architecture is built and
validated.

Inspect and smoke-test what was actually published:

```sh
docker buildx imagetools inspect \
  "${IMAGE_REPOSITORY}:${RELEASE_VERSION}"
docker buildx imagetools inspect \
  "${IMAGE_REPOSITORY}:alpine-${RELEASE_VERSION}"

docker pull "${IMAGE_REPOSITORY}:${RELEASE_VERSION}"
docker pull "${IMAGE_REPOSITORY}:alpine-${RELEASE_VERSION}"

./tests/docker-smoke.sh main \
  "${IMAGE_REPOSITORY}:${RELEASE_VERSION}"
./tests/docker-smoke.sh alpine \
  "${IMAGE_REPOSITORY}:alpine-${RELEASE_VERSION}"
```

After remote verification, create and push the Git tag using the repository's existing
plain semantic-version convention:

```sh
git tag -a "${RELEASE_VERSION}" -m "Release ${RELEASE_VERSION}"
git push origin main "${RELEASE_VERSION}"
```

Finally, update the Docker Hub overview if its usage contract or examples changed.

## Maintenance checklist

Review these items for every release and periodically between releases:

- Nginx base tags and their upstream support status
- pinned Python server packages in both variants
- GitHub Actions SHAs and release comments
- both image sizes and startup logs
- Docker Hub tags, digests, and published architecture
- README commands against the published image
- example dependency pins and all example smoke tests
- intentional root execution and listener-only health semantics
- accidental secrets, credentials, caches, or build outputs

## Documentation policy

Only `README.md` and `README-DEV.md` are public Markdown documents. Local agent notes,
project maps, and example notes remain ignored. Check the effective public set with:

```sh
git ls-files --cached --others --exclude-standard -- '*.md' |
  LC_ALL=C sort
```

The output must be exactly:

```text
README-DEV.md
README.md
```

Keep the consumer contract in `README.md`. Keep development, testing, release, and
maintenance procedures here. Do not make an ignored local note the only source of a
public behavior or contributor requirement.

## Intentional limitations

- Gunicorn and the Nginx master start as root; only Nginx workers drop privileges.
- The health check tests TCP listeners, not application readiness.
- Proxy timeouts remain fixed at `5s`/`120s`/`120s` unless the template is replaced.
- TLS termination, persistence, and external dependencies are outside the image.
- Base tags are not digest-locked.
