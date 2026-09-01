FROM nginx:1.30.4-alpine3.24

LABEL org.opencontainers.image.authors="alisharify <alisharifyofficial@gmail.com>" \
      org.opencontainers.image.title="gunicorn-uvicorn-nginx-alpine" \
      org.opencontainers.image.description="Run Python ASGI applications behind Nginx and Gunicorn with Uvicorn workers on Alpine Linux." \
      org.opencontainers.image.source="https://github.com/alisharify7/gunicorn-uvicorn-nginx" \
      org.opencontainers.image.url="https://github.com/alisharify7/gunicorn-uvicorn-nginx" \
      org.opencontainers.image.documentation="https://github.com/alisharify7/gunicorn-uvicorn-nginx#readme" \
      org.opencontainers.image.licenses="GPL-3.0-only"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/opt/venv/bin:${PATH}" \
    APP_MODULE="main:app" \
    GUNICORN_WORKER_CLASS="uvicorn_worker.UvicornWorker" \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4 \
    GUNICORN_TIMEOUT=120

RUN rm -f /etc/nginx/conf.d/default.conf \
    && apk add --no-cache \
        py3-pip \
        python3 \
    && python3 -m venv /opt/venv

COPY requirements.txt /opt/gunicorn-uvicorn-nginx/requirements.txt

RUN python -m pip install --no-cache-dir \
        --requirement /opt/gunicorn-uvicorn-nginx/requirements.txt

COPY nginx.conf /etc/nginx/nginx.conf
COPY custom.conf /opt/gunicorn-uvicorn-nginx/custom.conf
COPY --chmod=0755 start.sh /opt/gunicorn-uvicorn-nginx/start.sh
COPY main.py /app/main.py

WORKDIR /app

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["/opt/venv/bin/python", "-c", "import os, socket; targets = (('127.0.0.1', 80), (os.getenv('NGINX_UPSTREAM_ADDRESS', '127.0.0.1'), int(os.getenv('NGINX_UPSTREAM_PORT', os.getenv('GUNICORN_BIND_PORT', '8000'))))); [socket.create_connection(target, 1).close() for target in targets]"]

STOPSIGNAL SIGTERM

CMD ["/opt/gunicorn-uvicorn-nginx/start.sh"]
