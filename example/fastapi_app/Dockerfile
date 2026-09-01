ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:latest
FROM ${BASE_IMAGE}

# This demo uses process-local memory, so keep it on one worker.
ENV GUNICORN_WORKERS=1

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY main.py ./

# Build and run
# docker build -t fastapi-example .
# docker run -p 80:80 fastapi-example
# Test: curl http://localhost/docs
