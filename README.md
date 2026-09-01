# Gunicorn + Uvicorn + Nginx Docker Image

Two Docker base images for serving Python applications through Nginx and Gunicorn.
ASGI applications use the maintained `uvicorn-worker` package by default; WSGI
applications can explicitly select a standard Gunicorn worker.

```text
client -> Nginx :80 -> Gunicorn 127.0.0.1:8000 -> main:app
```

This all-in-one layout is intended for a single host or a simple Docker Compose
deployment. In Kubernetes and similar orchestrators, prefer one application process
per container and a platform-managed ingress or reverse proxy.

## Build the base images

The repository contains two build contexts:

| Target | Base image | Local tag |
| --- | --- | --- |
| `main` | `nginx:1.30.4-trixie` | `gunicorn-uvicorn-nginx:main-test` |
| `alpine` | `nginx:1.30.4-alpine3.24` | `gunicorn-uvicorn-nginx:alpine-test` |

Build both images with Docker Buildx Bake:

```sh
./docker/build.sh
```

The helper adds `--load`, so the resulting tags are available to the local Docker
daemon even when Buildx uses the `docker-container` driver. Build one target or use a
context directly:

```sh
./docker/build.sh main
docker build -t gunicorn-uvicorn-nginx:main-test docker/main
docker build -t gunicorn-uvicorn-nginx:alpine-test docker/alpine
```

Builds require Docker daemon access and network access to the base-image and Python
package registries.

## Quick start

A consumer image must install its dependencies at build time and copy an importable
application into `/app`. This example uses the locally built Debian image:

```dockerfile
ARG BASE_IMAGE=gunicorn-uvicorn-nginx:main-test
FROM ${BASE_IMAGE}

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY . ./
```

The default application target is `main:app`, and the default worker expects an ASGI
application.

```sh
docker build -t my-app .
docker run --rm -p 8080:80 my-app
curl --fail http://127.0.0.1:8080/
```

To consume a published image after this revision has been released, set
`BASE_IMAGE` to its immutable release tag or digest.

### Published tag status

The source tree is the runtime source of truth. As verified on 2026-09-01, Docker Hub
contains the older tags `latest`, `1.0.0`, `alpine-latest`, and `alpine-1.0.0`; those
images predate the runtime described here and must be republished before they can be
used with this contract. There is no published `alpine` tag. The example Dockerfiles
use the existing moving aliases as defaults but accept `--build-arg BASE_IMAGE=...`
so tests can use freshly built local images.

## Runtime contract

- `/app` is the working directory.
- `APP_MODULE` defaults to `main:app` and must resolve inside the consumer image.
- Nginx listens on port 80 and proxies to `127.0.0.1:8000` by default.
- The image installs only its pinned server stack. Application dependencies belong in
  the derived image.
- Startup never runs `pip` or contacts a package index.
- The bundled `/app/main.py` is a dependency-free ASGI smoke application. Consumers
  are expected to replace it.

## Application server configuration

| Variable | Default | Description |
| --- | --- | --- |
| `APP_MODULE` | `main:app` | Python application URI passed separately to Gunicorn |
| `GUNICORN_WORKER_CLASS` | `uvicorn_worker.UvicornWorker` | Worker used when arguments are generated |
| `GUNICORN_WORKERS` | `2` | Generated worker count; must be greater than zero |
| `GUNICORN_THREADS` | `4` | Generated thread count, used only for the exact `gthread` worker |
| `GUNICORN_TIMEOUT` | `120` | Generated Gunicorn worker-silence timeout in seconds; `0` is allowed |
| `GUNICORN_BIND_ADDRESS` | `127.0.0.1` | Generated Gunicorn listener address |
| `GUNICORN_BIND_PORT` | `8000` | Generated Gunicorn listener port |
| `NGINX_UPSTREAM_ADDRESS` | `127.0.0.1` | Address used by Nginx's upstream proxy |
| `NGINX_UPSTREAM_PORT` | `GUNICORN_BIND_PORT` | Upstream port when it is not explicitly set |
| `GUNICORN_CMD_ARGS` | generated | Non-empty value replaces all generated Gunicorn flags |

Empty environment values fall back to the defaults. When `GUNICORN_CMD_ARGS` is
non-empty, Gunicorn parses the string itself, including quoted values. It does not
replace `APP_MODULE`.

If custom arguments change `--bind`, independently align
`NGINX_UPSTREAM_ADDRESS` and `NGINX_UPSTREAM_PORT`:

```dockerfile
ENV APP_MODULE=src.api:app \
    GUNICORN_CMD_ARGS="--worker-class uvicorn_worker.UvicornWorker --bind 127.0.0.1:9000 --workers 4 --timeout 60" \
    NGINX_UPSTREAM_ADDRESS=127.0.0.1 \
    NGINX_UPSTREAM_PORT=9000
```

Addresses may be hostnames, IPv4 addresses, or unbracketed IPv6 addresses. Ports and
generated numeric settings are validated before either service starts.

### WSGI applications

The default worker is ASGI-only. Flask and other WSGI applications must select a
compatible Gunicorn worker:

```dockerfile
ENV GUNICORN_WORKER_CLASS=gthread \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4
```

The Flask example under `example/flask_app/` is built and exercised by the smoke
suite.

## Nginx configuration

The image deliberately exposes two configuration scopes:

| Path | Nginx context | Suitable content |
| --- | --- | --- |
| `/etc/nginx/conf.d/*.conf` | `http` | `map`, `upstream`, or complete `server {}` blocks |
| `/etc/nginx/server.d/*.conf` | Built-in `server` | Server directives and additional `location` blocks |

For example, a derived image can add a response header to the built-in server:

```nginx
add_header X-Example-Config "enabled" always;
```

```dockerfile
COPY add_header.conf /etc/nginx/server.d/
```

The image-owned proxy template is
`/opt/gunicorn-uvicorn-nginx/custom.conf`. Startup substitutes the Nginx upstream
address and port, writes `/etc/nginx/server.d/default.conf`, and runs `nginx -t`
before launching the services. A readable `/app/custom.conf` still takes precedence
for backward compatibility and produces a deprecation warning; derived images should
replace the image-owned template instead.

The built-in proxy supports HTTP/1.1 and WebSocket upgrades. Request and response
buffering are enabled. An application can return `X-Accel-Buffering: no` for an SSE or
streaming response. Proxy connect, send, and read timeouts are 5, 120, and 120 seconds;
replace the template when an application needs different proxy timing.

Hidden paths are denied except `/.well-known/`, which remains available to application
routes such as OpenID Connect discovery. To serve ACME challenge files directly from
Nginx, add a more specific `location ^~ /.well-known/acme-challenge/` in a
server-scope snippet.

Nginx intentionally derives `X-Forwarded-Proto` and `X-Forwarded-Port` from its direct
connection instead of trusting client-supplied headers. When the container is behind a
trusted TLS-terminating proxy, replace the server template with a policy that trusts
forwarded headers only from that proxy; otherwise the application will see the
internal `http`/`80` connection.

## Lifecycle and health check

`start.sh` remains PID 1 and supervises both Gunicorn and Nginx. An unexpected exit
from either child stops its peer and makes the container exit non-zero. On `TERM`,
`INT`, or `QUIT`, the supervisor asks Gunicorn to terminate gracefully and sends
Nginx `QUIT`, then reaps both children. `HUP` reloads both services.

The Docker health check opens TCP connections to Nginx and the configured upstream.
It verifies that both listeners accept connections, but it is not an application-level
readiness check and does not prove that external dependencies are healthy.

## Examples

Every example accepts a `BASE_IMAGE` build argument. Build the base images first, then
exercise an example against the exact local source revision:

```sh
docker build \
  --build-arg BASE_IMAGE=gunicorn-uvicorn-nginx:alpine-test \
  -t gunicorn-example \
  example/simple
docker run --rm -p 8080:80 gunicorn-example
curl --fail http://127.0.0.1:8080/
```

| Directory | Demonstrates | Local base |
| --- | --- | --- |
| [`example/simple/`](example/simple/) | Minimal FastAPI application | Alpine |
| [`example/fastapi_app/`](example/fastapi_app/) | Validation and create/read/delete routes with process-local storage | Debian |
| [`example/flask_app/`](example/flask_app/) | Flask with Gunicorn's `gthread` WSGI worker | Alpine |
| [`example/config_gunicorn/`](example/config_gunicorn/) | Four ASGI workers and an aligned internal port of 6565 | Alpine |
| [`example/config_nginx/`](example/config_nginx/) | A server-scope response-header snippet | Alpine |
| [`example/static_files/`](example/static_files/) | FastAPI HTML response and mounted static files | Debian |

The FastAPI and Flask examples use process-local lists. They deliberately run one
worker where consistency matters; production deployments should use shared durable
storage before increasing the worker count.

## Validation

Fast checks require POSIX `sh` and Python 3. ShellCheck is used when available and is
required in CI:

```sh
./tests/static.sh
```

Full smoke tests require Docker, `curl`, Python 3, daemon access, and network access
when an image must be built:

```sh
./tests/docker-smoke.sh main
./tests/docker-smoke.sh alpine
```

Reuse the locally built Bake images and also test all examples:

```sh
./tests/docker-smoke.sh main gunicorn-uvicorn-nginx:main-test
./tests/docker-smoke.sh alpine gunicorn-uvicorn-nginx:alpine-test
./tests/examples-smoke.sh main gunicorn-uvicorn-nginx:main-test
./tests/examples-smoke.sh alpine gunicorn-uvicorn-nginx:alpine-test
```

The base-image smoke suite covers exact fallback HTTP output, Docker health status,
offline startup, graceful shutdown, symmetric Gunicorn/Nginx supervision, invalid
configuration rejection, custom Gunicorn arguments, `HUP` reloads, `QUIT` shutdown,
WSGI `gthread`, both Nginx extension scopes, legacy `/app/custom.conf`,
application-owned `/.well-known/` routes, and a WebSocket upgrade/echo/close lifecycle.
CI builds both variants and runs their corresponding examples.

## Intentional limitations

- Nginx binds privileged port 80. Its master process and Gunicorn start as root;
  Nginx workers drop to the image's `nginx` user, but the container is not fully
  non-root.
- Base tags and Python server packages are pinned, but base images are not
  digest-locked. Rebuilds can therefore pick up a changed manifest for the same tag.
- The health check is listener-level, not application-level readiness.
- TLS termination, persistent application data, and external-service supervision are
  outside the image's scope.
- Worker counts, request limits, buffering, and timeouts are safe starting points, not
  universal performance settings. Tune them with representative load tests.

## References

- [Gunicorn documentation](https://gunicorn.org/)
- [Uvicorn deployment documentation](https://www.uvicorn.org/deployment/)
- [Nginx documentation](https://nginx.org/en/docs/)
- [Docker build best practices](https://docs.docker.com/build/building/best-practices/)
