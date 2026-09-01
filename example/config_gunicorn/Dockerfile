ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:alpine-latest
FROM ${BASE_IMAGE}

# Tune the ASGI worker without exposing Gunicorn outside the container.
ENV GUNICORN_WORKERS=4 \
    GUNICORN_TIMEOUT=60 \
    GUNICORN_BIND_PORT=6565 \
    NGINX_UPSTREAM_PORT=6565

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY main.py ./
