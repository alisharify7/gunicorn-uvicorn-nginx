FROM nginx:1.27.3-alpine

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

COPY nginx.conf /etc/nginx/nginx.conf
COPY custom.conf .



# Copy application files and dependencies
COPY . .
COPY requirements.txt .
COPY start.sh .

RUN apk update && apk add --no-cache python3 python3-pip \
    && pip3 config set global.break-system-packages true \
    && pip3 install --no-cache-dir gunicorn uvicorn \
    && pip3 install --no-cache-dir -r requirements.txt


EXPOSE 80
CMD ["sh", "start.sh"]
