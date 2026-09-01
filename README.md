# Gunicorn + Uvicorn + Nginx

A reusable Docker base image for serving Python web applications with Nginx and
Gunicorn. ASGI applications run with Uvicorn workers by default, while WSGI
applications can select a standard Gunicorn worker.

```text
client -> Nginx :80 -> Gunicorn 127.0.0.1:8000 -> application
```

> **Release status**
>
> This guide documents the v2 runtime contract. As verified on 2026-09-01, the
> existing Docker Hub aliases still point to the legacy v1 images. Use this contract
> only after a matching v2 tag is published or the moving aliases are refreshed.
> Publishing is covered in the
> [maintainer guide](https://github.com/alisharify7/gunicorn-uvicorn-nginx/blob/main/README-DEV.md).

## Why use this image?

- **Ready-made serving stack:** Nginx, Gunicorn, Uvicorn, and their integration are
  already configured.
- **ASGI and WSGI support:** use the default Uvicorn worker for FastAPI or Starlette,
  or select `gthread` for Flask, Django WSGI, and similar applications.
- **Container-aware lifecycle:** one PID 1 supervisor handles graceful shutdown,
  reloads, child failures, and process cleanup.
- **Useful Nginx defaults:** HTTP/1.1 proxying, WebSocket upgrades, gzip, buffering,
  request-size limits, and forwarding headers are configured.
- **Environment-based tuning:** change the application module, worker class, worker
  count, timeout, and internal bind without replacing the entrypoint.
- **Extensible Nginx configuration:** add HTTP-scope or server-scope snippets from a
  consumer image.
- **Predictable startup:** application packages are installed when your image is
  built; container startup does not run `pip` or contact a package registry.
- **Built-in health and supervision:** Docker can detect listener failures, and an
  unexpected Gunicorn or Nginx exit stops the whole container.
- **Two variants:** choose Debian for broader compatibility or Alpine for a smaller
  base.

## Architecture

```text
                         one Docker container
┌────────┐   port 80   ┌─────────┐   loopback :8000   ┌──────────┐
│ client │ ──────────> │  Nginx  │ ─────────────────> │ Gunicorn │
└────────┘             └─────────┘                    └────┬─────┘
                                                         │
                                                Uvicorn or WSGI workers
                                                         │
                                                         v
                                                   your Python app

             start.sh is PID 1 and supervises Nginx + Gunicorn
```

Only Nginx is exposed publicly. Gunicorn listens on the container loopback interface
by default, so application traffic follows one consistent path:

1. Nginx accepts the client connection on port `80`.
2. Nginx handles proxy headers, gzip, buffering, uploads, and WebSocket upgrades.
3. Nginx proxies the request to Gunicorn on `127.0.0.1:8000`.
4. Gunicorn distributes work across its worker processes.
5. The worker calls your ASGI or WSGI application.

The entrypoint supervises both Nginx and Gunicorn. If either one dies unexpectedly,
the other is stopped and the container exits non-zero instead of remaining partially
alive.

## Docker Hub images

| Variant | Moving tag | Base image | Best fit |
| --- | --- | --- | --- |
| Debian | `alisharify7/gunicorn-uvicorn-nginx:latest` | `nginx:1.30.4-trixie` | Compatibility and familiar Debian tooling |
| Alpine | `alisharify7/gunicorn-uvicorn-nginx:alpine-latest` | `nginx:1.30.4-alpine3.24` | Smaller base and Alpine-based deployments |

After the v2 aliases have been refreshed, pull an image directly from Docker Hub:

```sh
docker pull alisharify7/gunicorn-uvicorn-nginx:latest
docker pull alisharify7/gunicorn-uvicorn-nginx:alpine-latest
```

Moving aliases can change and can lag behind the Git repository. Check available tags
and digests on
[Docker Hub](https://hub.docker.com/r/alisharify7/gunicorn-uvicorn-nginx/tags).
For production, prefer a verified versioned tag or digest.

## Quick start with FastAPI

Your application only needs to extend the Docker Hub image, install its dependencies,
and copy importable code into `/app`.

The example below uses the moving `latest` alias and therefore assumes it has already
been refreshed to v2. In production, replace it with a verified versioned tag or
digest.

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
FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY main.py ./
```

Build your application image and run it:

```sh
docker build -t my-fastapi-app .
docker run --rm --name my-fastapi-app -p 8080:80 my-fastapi-app
```

Open <http://127.0.0.1:8080/> or test it from another terminal:

```sh
curl --fail http://127.0.0.1:8080/
```

This builds your application on top of the published base image; it does not build
the base image itself.

### Use Alpine instead

Change only the first Dockerfile line:

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest
```

Application dependencies still need to provide wheels or build successfully on
Alpine. Choose Debian when a package depends on glibc or is difficult to compile
against musl.

## Application contract

- `/app` is the working directory.
- `APP_MODULE` defaults to `main:app`.
- The default worker expects an ASGI application.
- Application dependencies must be installed in the consumer Dockerfile.
- Startup never installs packages or contacts an index.
- The base image's bundled `main.py` is only a smoke application; your image should
  replace it with real application code.
- Keep the inherited `CMD` unless you intentionally want to bypass Nginx and the PID 1
  supervisor.

For example, if the application object is `app` inside `/app/src/api.py`:

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

ENV APP_MODULE=src.api:app

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY src ./src
```

## ASGI and WSGI applications

### ASGI: FastAPI, Starlette, and similar frameworks

No worker configuration is required. The default is:

```text
uvicorn_worker.UvicornWorker
```

HTTP and WebSocket applications work through the same Nginx endpoint.

### WSGI: Flask and Django WSGI

Select a compatible Gunicorn worker explicitly:

```dockerfile
ENV GUNICORN_WORKER_CLASS=gthread \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4
```

For a Django WSGI application, also point Gunicorn at its application object:

```dockerfile
ENV APP_MODULE=myproject.wsgi:application \
    GUNICORN_WORKER_CLASS=gthread
```

See
[`example/flask_app/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/flask_app)
for a complete Flask consumer image.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_MODULE` | `main:app` | Gunicorn application URI |
| `GUNICORN_WORKER_CLASS` | `uvicorn_worker.UvicornWorker` | Worker used for generated Gunicorn arguments |
| `GUNICORN_WORKERS` | `2` | Worker process count |
| `GUNICORN_THREADS` | `4` | Thread count, emitted only for the exact `gthread` worker |
| `GUNICORN_TIMEOUT` | `120` | Worker-silence timeout in seconds; `0` disables it |
| `GUNICORN_BIND_ADDRESS` | `127.0.0.1` | Internal Gunicorn listener address |
| `GUNICORN_BIND_PORT` | `8000` | Internal Gunicorn listener port |
| `NGINX_UPSTREAM_ADDRESS` | `127.0.0.1` | Address used by Nginx |
| `NGINX_UPSTREAM_PORT` | value of `GUNICORN_BIND_PORT` | Port used by Nginx when not explicitly set |
| `GUNICORN_CMD_ARGS` | generated | Complete custom Gunicorn flags when non-empty |

Empty values fall back to the defaults. Ports and generated numeric settings are
validated before either service starts.

### Tune workers and timeout

Set values in the consumer Dockerfile:

```dockerfile
ENV GUNICORN_WORKERS=4 \
    GUNICORN_TIMEOUT=60
```

Or configure them when the container starts:

```sh
docker run --rm -p 8080:80 \
  -e GUNICORN_WORKERS=4 \
  -e GUNICORN_TIMEOUT=60 \
  my-fastapi-app
```

Worker count depends on CPU, memory, request behavior, and workload. Benchmark the
application instead of assuming a universal value.

### Change the internal port

When generated settings are used, changing `GUNICORN_BIND_PORT` also changes the
default Nginx upstream port:

```dockerfile
ENV GUNICORN_BIND_PORT=9000
```

The public container port remains `80`.

### Supply complete Gunicorn arguments

A non-empty `GUNICORN_CMD_ARGS` replaces the generated worker, bind, worker-count,
thread, and timeout flags. It does not replace `APP_MODULE`.

If custom arguments change the bind, align the Nginx upstream explicitly:

```dockerfile
ENV APP_MODULE=src.api:app \
    GUNICORN_CMD_ARGS="--worker-class uvicorn_worker.UvicornWorker --bind 127.0.0.1:9000 --workers 4 --timeout 60" \
    NGINX_UPSTREAM_ADDRESS=127.0.0.1 \
    NGINX_UPSTREAM_PORT=9000
```

## Nginx features and customization

The default proxy configuration includes:

- HTTP/1.1 proxying and WebSocket upgrades
- gzip for common text, JSON, JavaScript, XML, and SVG responses
- a `250m` maximum request body
- request and response buffering
- `5s` connect and `120s` send/read proxy timeouts
- `Host`, real-IP, and forwarding headers
- hidden-path protection while preserving application-owned `/.well-known/` routes

### Add server behavior

Two extension locations serve different Nginx scopes:

| Path | Nginx context | Use it for |
| --- | --- | --- |
| `/etc/nginx/conf.d/*.conf` | `http` | `map`, `upstream`, or complete `server {}` blocks |
| `/etc/nginx/server.d/*.conf` | Built-in server | Headers, server directives, and additional `location` blocks |

For example, add a header to the built-in server:

`add_header.conf`:

```nginx
add_header X-My-App "enabled" always;
```

Consumer Dockerfile:

```dockerfile
COPY add_header.conf /etc/nginx/server.d/add_header.conf
```

Do not name a server snippet `default.conf`; startup owns and rewrites that file. Do
not mount the entire `/etc/nginx/server.d` directory read-only because startup must
write its rendered proxy configuration there.

### Replace the built-in proxy template

Copy a server-scope template over the image-owned file:

```dockerfile
COPY custom.conf /opt/gunicorn-uvicorn-nginx/custom.conf
```

The template must retain these literal placeholders:

```text
${NGINX_UPSTREAM_ADDRESS}
${NGINX_UPSTREAM_PORT}
```

It must contain server directives or `location` blocks, not another `server {}`
block. The legacy `/app/custom.conf` override still works but is deprecated.

### WebSockets, SSE, and streaming

- WebSocket upgrade headers are handled automatically; no additional Nginx snippet is
  required.
- Request and response buffering are enabled by default.
- An SSE or streaming response can return `X-Accel-Buffering: no` to disable Nginx
  response buffering for that response.
- Applications needing proxy timeouts longer than `120s` must replace the proxy
  template.

### Forwarded headers and TLS proxies

Nginx derives `X-Real-IP`, `X-Forwarded-Proto`, `X-Forwarded-Port`, and
`X-Forwarded-Host` from its direct connection. `X-Forwarded-For` preserves an incoming
chain and appends the direct remote address, so an application must not treat that
entire chain as trusted by default.

Behind a trusted TLS-terminating proxy, the application sees the container's internal
`http`/`80` connection unless the proxy template defines a deliberate trusted-proxy
policy. Define which proxy addresses are trusted before using forwarded values for
security decisions.

## Lifecycle and health check

`start.sh` stays PID 1 and supervises both services:

- `TERM`, `INT`, and `QUIT` trigger graceful shutdown.
- `HUP` reloads Gunicorn and Nginx.
- An unexpected exit from either service stops its peer and exits non-zero.
- Child processes are reaped instead of being left as zombies.

Restart the container after changing the proxy template because `HUP` reloads the
running services but does not render the template again.

The Docker health check opens TCP connections to both Nginx and the configured
Gunicorn upstream. It proves that both listeners accept connections, but it is not an
HTTP readiness check and does not validate databases, queues, or other dependencies.

For application readiness, add a framework-level health endpoint and configure your
deployment platform to call it.

## Examples

| Directory | Demonstrates | Variant |
| --- | --- | --- |
| [`example/simple/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/simple) | Minimal FastAPI application | Alpine |
| [`example/fastapi_app/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/fastapi_app) | Validation and create/read/delete routes | Debian |
| [`example/flask_app/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/flask_app) | Flask with the `gthread` worker | Alpine |
| [`example/config_gunicorn/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/config_gunicorn) | Worker tuning and a custom internal port | Alpine |
| [`example/config_nginx/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/config_nginx) | A server-scope Nginx header | Alpine |
| [`example/static_files/`](https://github.com/alisharify7/gunicorn-uvicorn-nginx/tree/main/example/static_files) | FastAPI HTML and static files | Debian |

Each example extends a Docker Hub image and can be adapted as an application
Dockerfile.

## When this image is a good fit

Use it when:

- you want a simple, reusable Nginx + Gunicorn container for one host or Docker
  Compose;
- you want consistent ASGI/WSGI process management without rebuilding the serving
  stack for every project;
- environment-based worker tuning and small Nginx extensions are enough.

Consider separate containers when:

- an orchestrator already provides ingress, health, scaling, and process lifecycle;
- Nginx and application workers must scale independently;
- strict non-root execution is required;
- the deployment needs a specialized proxy, service mesh, or trusted-forwarded-header
  policy.

## Limitations

- Gunicorn and the Nginx master start as root; only Nginx workers drop privileges.
- The image intentionally runs two supervised services in one container.
- Upstream Nginx base image references use version tags rather than immutable
  digests.
- The built-in health check is listener-level rather than application readiness.
- TLS termination, persistent application data, and external-service supervision are
  outside the image.
- Proxy and worker defaults are starting points, not universal performance settings.

## Development and maintenance

Development builds, tests, CI, dependency updates, and release publishing are kept out
of this consumer guide. See the
[maintainer guide](https://github.com/alisharify7/gunicorn-uvicorn-nginx/blob/main/README-DEV.md).

## License

[GPL-3.0](https://github.com/alisharify7/gunicorn-uvicorn-nginx/blob/main/LICENSE)
