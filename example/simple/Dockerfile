# simle docker file without any custom config
FROM  alisharify7/gunicorn-uvicorn-nginx:alpine-1.0.0

WORKDIR /app
COPY requirements.txt .
COPY . .
RUN pip3 install -r requirements.txt

