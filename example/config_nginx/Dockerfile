ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:alpine-latest
FROM ${BASE_IMAGE}

COPY add_header.conf /etc/nginx/server.d/

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY main.py ./
