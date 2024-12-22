FROM alisharify7/gunicorn-uvicorn-nginx:alpine-1.0.0


# change gunicorn config
ENV GUNICORN_WORKERS 4
ENV GUNICORN_THREADS 4
ENV GUNICORN_TIMEOUT 60
ENV GUNICORN_BIND_PORT 6565
ENV GUNICORN_BIND_ADDRESS 0.0.0.0

# or you can change gunicorn starter command totally
# ENV GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker --bind 127.0.0.1 --workers 2 --threads 2 --timeout 55 --log-level=info"
# if this env is provided the all other env config will be overided and ignored


WORKDIR /app
COPY . .
COPY requirements.txt .
RUN pip3 install -r requirements.txt
