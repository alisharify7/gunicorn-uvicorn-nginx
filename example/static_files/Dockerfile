ARG BASE_IMAGE=alisharify7/gunicorn-uvicorn-nginx:latest
FROM ${BASE_IMAGE}

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY main.py ./
COPY static ./static

# Build and run
# docker build -t static-files-example .
# docker run -p 80:80 static-files-example
# Test: open http://localhost in browser
