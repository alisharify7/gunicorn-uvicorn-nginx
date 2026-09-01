# Gunicorn + Uvicorn + Nginx

Reusable Docker base images for running Python web applications behind Nginx and
Gunicorn. ASGI applications use Uvicorn workers by default; WSGI applications can
select a standard Gunicorn worker.

```text
client -> Nginx :80 -> Gunicorn 127.0.0.1:8000 -> your application
```

This image is a practical fit for a single server, Docker Compose, or other simple
deployments where keeping Nginx and the Python application in one container is useful.
For Kubernetes and similar orchestrators, separate application and ingress containers
are usually a better fit.

> [!IMPORTANT]
> As verified on 2026-09-01, the Docker Hub aliases still contain the legacy v1
> images and do not yet provide the source contract documented here. Build from source
> until this revision is published, then verify the remote tag or digest before use.

## Choose an image

| Variant | Published alias after refresh | Base image |
| --- | --- | --- |
| Debian | `alisharify7/gunicorn-uvicorn-nginx:latest` | `nginx:1.30.4-trixie` |
| Alpine | `alisharify7/gunicorn-uvicorn-nginx:alpine-latest` | `nginx:1.30.4-alpine3.24` |

Source and image releases happen independently, so moving aliases can lag behind this
repository. Check the tag and digest on
[Docker Hub](https://hub.docker.com/r/alisharify7/gunicorn-uvicorn-nginx/tags) before
deploying. For production, prefer a verified versioned tag or digest. If a matching
release has not been published yet, [build the base image from source](#build-from-source).

## Quick start: FastAPI

Create these three files:

```text
my-app/
├── Dockerfile
├── main.py
└── requirements.txt
```

`main.py`:

```python
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello from FastAPI"}
```

`requirements.txt`:

```text
fastapi==0.141.1
```

`Dockerfile`:

```dockerfile
ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:latest
FROM ${BASE_IMAGE}

WORKDIR /app

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY main.py ./
```

Build and run the application:

```sh
docker build -t my-fastapi-app .
docker run --rm --name my-fastapi-app -p 8080:80 my-fastapi-app
```

Open <http://127.0.0.1:8080/> or test it from another terminal:

```sh
curl --fail http://127.0.0.1:8080/
```

Application dependencies are installed while the consumer image is built. Container
startup never runs `pip` and does not contact a package registry.

### Use the Alpine variant

Override the base image during the consumer build:

```sh
docker build \
  --build-arg BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:alpine-latest \
  -t my-fastapi-app:alpine \
  .
```

## Build from source

Build both base variants from the checked-out source:

```sh
git clone https://github.com/alisharify7/gunicorn-uvicorn-nginx.git
cd gunicorn-uvicorn-nginx
./docker/build.sh
```

This creates:

```text
gunicorn-uvicorn-nginx:main-test
gunicorn-uvicorn-nginx:alpine-test
```

Use one of those local tags when building your application:

```sh
docker build \
  --build-arg BASE_IMAGE=gunicorn-uvicorn-nginx:main-test \
  -t my-fastapi-app \
  ./path/to/my-app
```

Build only one variant if needed:

```sh
./docker/build.sh main
./docker/build.sh alpine
```

Docker, Docker Buildx, daemon access, and network access to image and Python package
registries are required.

## Application layout

The container working directory is `/app`. By default, Gunicorn imports `app` from
`/app/main.py` using the application URI `main:app`.

For a different layout, set `APP_MODULE` in the consumer Dockerfile. For example,
`/app/src/api.py` containing `app` uses:

```dockerfile
ENV APP_MODULE=src.api:app
```

Do not replace the base image `CMD` unless you intentionally want to bypass its Nginx
and Gunicorn supervisor.

## WSGI applications

The default worker is ASGI-only. Flask, Django WSGI, and other WSGI applications must
select a compatible worker:

```dockerfile
ENV GUNICORN_WORKER_CLASS=gthread \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4
```

The [`example/flask_app/`](example/flask_app/) directory contains a working Flask
consumer image.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_MODULE` | `main:app` | Gunicorn application URI |
| `GUNICORN_WORKER_CLASS` | `uvicorn_worker.UvicornWorker` | Worker used for generated Gunicorn arguments |
| `GUNICORN_WORKERS` | `2` | Worker process count |
| `GUNICORN_THREADS` | `4` | Thread count, emitted only for the exact `gthread` worker |
| `GUNICORN_TIMEOUT` | `120` | Gunicorn worker-silence timeout in seconds; `0` disables it |
| `GUNICORN_BIND_ADDRESS` | `127.0.0.1` | Internal Gunicorn listener address |
| `GUNICORN_BIND_PORT` | `8000` | Internal Gunicorn listener port |
| `NGINX_UPSTREAM_ADDRESS` | `127.0.0.1` | Address Nginx proxies to |
| `NGINX_UPSTREAM_PORT` | value of `GUNICORN_BIND_PORT` | Port Nginx proxies to when not explicitly set |
| `GUNICORN_CMD_ARGS` | generated | Complete custom Gunicorn flags when non-empty |

Empty values fall back to the defaults. Numeric values and ports are validated before
either service starts.

A non-empty `GUNICORN_CMD_ARGS` replaces the generated worker, bind, worker-count,
thread, and timeout flags. It does not replace `APP_MODULE`. If custom arguments
change the Gunicorn bind, align the Nginx upstream too:

```dockerfile
ENV APP_MODULE=src.api:app \
    GUNICORN_CMD_ARGS="--worker-class uvicorn_worker.UvicornWorker --bind 127.0.0.1:9000 --workers 4 --timeout 60" \
    NGINX_UPSTREAM_ADDRESS=127.0.0.1 \
    NGINX_UPSTREAM_PORT=9000
```

## Nginx customization

Two extension locations are available:

| Path | Nginx context | Use it for |
| --- | --- | --- |
| `/etc/nginx/conf.d/*.conf` | `http` | `map`, `upstream`, or complete `server {}` blocks |
| `/etc/nginx/server.d/*.conf` | Built-in server | Headers, server directives, and additional `location` blocks |

For example, add a response header to the built-in server:

```nginx
add_header X-My-App "enabled" always;
```

```dockerfile
COPY add_header.conf /etc/nginx/server.d/add_header.conf
```

Do not name a server snippet `default.conf`; startup owns and rewrites that file. Do
not mount the entire `/etc/nginx/server.d` directory read-only because startup must
write its rendered proxy configuration there.

To replace the built-in proxy behavior, copy a server-scope template over:

```dockerfile
COPY custom.conf /opt/gunicorn-uvicorn-nginx/custom.conf
```

The template must retain these literal placeholders:

```text
${NGINX_UPSTREAM_ADDRESS}
${NGINX_UPSTREAM_PORT}
```

It must contain directives or `location` blocks, not another `server {}` block. The
legacy `/app/custom.conf` override still works but is deprecated.

Operational defaults:

- HTTP/1.1 and WebSocket upgrades are supported.
- `client_max_body_size` is `250m`.
- Proxy connect/send/read timeouts are fixed at `5s`/`120s`/`120s` unless the
  template is replaced.
- Request and response buffering are enabled. An application can return
  `X-Accel-Buffering: no` for SSE or streaming responses.
- Hidden paths are denied, while application-owned `/.well-known/` routes remain
  reachable.
- Client-supplied forwarding headers are not trusted. Behind a trusted
  TLS-terminating proxy, provide an explicit trusted-proxy policy in the template.

## Lifecycle and health

The image entrypoint remains PID 1 and supervises both Gunicorn and Nginx. If either
service exits unexpectedly, its peer is stopped and the container exits non-zero.
`TERM`, `INT`, and `QUIT` trigger graceful shutdown; `HUP` reloads both services.
Restart the container after changing the proxy template because `HUP` does not render
it again.

The Docker health check verifies that the Nginx and Gunicorn TCP listeners accept
connections. It is not an HTTP readiness check and does not verify databases, queues,
or other application dependencies.

## Examples

| Directory | Demonstrates | Base variant |
| --- | --- | --- |
| [`example/simple/`](example/simple/) | Minimal FastAPI application | Alpine |
| [`example/fastapi_app/`](example/fastapi_app/) | Validation and create/read/delete routes | Debian |
| [`example/flask_app/`](example/flask_app/) | Flask with the `gthread` WSGI worker | Alpine |
| [`example/config_gunicorn/`](example/config_gunicorn/) | Worker tuning and a custom internal port | Alpine |
| [`example/config_nginx/`](example/config_nginx/) | A server-scope Nginx header | Alpine |
| [`example/static_files/`](example/static_files/) | FastAPI HTML and static files | Debian |

Example Dockerfiles accept a `BASE_IMAGE` build argument. When testing a source
checkout, override it with the corresponding freshly built local image.

## Limitations

- Gunicorn and the Nginx master start as root; only Nginx workers drop privileges.
- The image runs two supervised services in one container.
- Base image tags are pinned but not digest-locked.
- TLS termination, persistent application data, and external-service supervision are
  outside the image.
- Proxy settings and worker defaults are starting points; tune them with realistic
  load tests.

## Development and maintenance

Building, testing, changing, and publishing the base images is documented in the
[maintainer guide](README-DEV.md).

## License

[GPL-3.0](LICENSE)
