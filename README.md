# Gunicorn + Uvicorn + Nginx Docker Image

Production-ready Docker image combining **Gunicorn**, **Uvicorn**, and **Nginx** for deploying Python web applications.

**Architecture:** Nginx (reverse proxy) → Gunicorn/Uvicorn (app server) → Your Python app

<img src="https://raw.githubusercontent.com/free-programmers/gunicorn-uvicorn-nginx/refs/heads/main/docs/flow.png" width="600">

---

## Quick Start

**Requirements:**
- Project must have `main.py` with an `app` object (e.g., `FastAPI()`, `Flask()`)
- `requirements.txt` in the project root

**Simple Dockerfile:**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Run:**
```bash
docker build -t my-app .
docker run -p 80:80 my-app
```

Visit `http://localhost`

---

## Component Configuration

### Gunicorn (App Server)

Configure via environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GUNICORN_WORKERS` | 2 | Number of worker processes |
| `GUNICORN_THREADS` | 4 | Threads per worker |
| `GUNICORN_TIMEOUT` | 120 | Request timeout (seconds) |
| `GUNICORN_BIND_ADDRESS` | 127.0.0.1 | Bind address |
| `GUNICORN_BIND_PORT` | 8000 | Bind port |
| `GUNICORN_CMD_ARGS` | (full command) | Override entire command |

**Example:**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

ENV GUNICORN_WORKERS=4
ENV GUNICORN_THREADS=8
ENV GUNICORN_TIMEOUT=60
ENV GUNICORN_BIND_ADDRESS=0.0.0.0

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Custom Command:**
```dockerfile
ENV GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --workers 4 --timeout 60"
```

---

### Nginx (Reverse Proxy)

Mount custom Nginx config to `/etc/nginx/conf.d/`:

**custom.conf:**
```nginx
server {
    listen 80;
    server_name localhost;
    
    # Custom settings (added to default server block)
    client_max_body_size 100M;
    proxy_read_timeout 120s;
}
```

**Dockerfile:**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

COPY custom.conf /etc/nginx/conf.d/

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

---

## Image Variants

- `alisharify7/gunicorn-uvicorn-nginx:latest` - Ubuntu-based
- `alisharify7/gunicorn-uvicorn-nginx:alpine` - Alpine Linux (smaller, faster)

---

## Examples

See [examples directory](https://github.com/free-programmers/gunicorn-uvicorn-nginx/tree/main/example) for:
- FastAPI applications
- Flask applications
- Static file serving
- Environment configuration

---

## Resources

- [Gunicorn Documentation](https://docs.gunicorn.org/)
- [Uvicorn Documentation](https://www.uvicorn.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)
