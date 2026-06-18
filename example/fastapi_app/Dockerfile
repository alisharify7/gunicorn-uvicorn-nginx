FROM alisharify7/gunicorn-uvicorn-nginx:latest

ENV GUNICORN_WORKERS=4
ENV GUNICORN_THREADS=8

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .

# Build and run
# docker build -t fastapi-example .
# docker run -p 80:80 fastapi-example
# Test: curl http://localhost/docs
