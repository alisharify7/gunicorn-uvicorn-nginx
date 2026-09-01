ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:alpine-latest
FROM ${BASE_IMAGE}

# Flask is WSGI, so select Gunicorn's threaded WSGI worker explicitly.
ENV GUNICORN_WORKER_CLASS=gthread \
    GUNICORN_WORKERS=1 \
    GUNICORN_THREADS=4

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY main.py ./

# Build and run
# docker build -t flask-example .
# docker run -p 80:80 flask-example
# Test: curl http://localhost/
