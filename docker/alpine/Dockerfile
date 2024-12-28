FROM nginx:1.27.3-alpine

LABEL maintainer="alisharify <alisharifyofficial@gmail.com>"
LABEL version="alpine-latest"
LABEL description="Deploy Python web apps with Docker using Nginx, Gunicorn/Uvicorn for scalability and performance."
LABEL license="GPL-3.0"

RUN rm /etc/nginx/conf.d/default.conf

# Python environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Gunicorn environment variables
ENV GUNICORN_WORKERS 2
ENV GUNICORN_THREADS 4
ENV GUNICORN_TIMEOUT 120

# Set working directory
WORKDIR /app

COPY . .
COPY nginx.conf /etc/nginx/nginx.conf
COPY requirements.txt .

COPY start.sh /opt/start.sh

RUN apk update && apk add --no-cache python3 py3-pip \
    && pip3 config set global.break-system-packages true \
    && python3 -m pip install --upgrade pip \
    && pip3 install --no-cache-dir --upgrade gunicorn uvicorn pyfiglet \
    && pip3 install --no-cache-dir -r requirements.txt


EXPOSE 80
CMD ["sh", "/opt/start.sh"]
