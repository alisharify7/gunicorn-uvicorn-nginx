# simle docker file without any custom config
FROM  alisharify7/gunicorn-uvicorn-nginx:alpine-1.0.0

COPY add_header.conf /etc/nginx/conf.d/

WORKDIR /app
COPY requirements.txt .
COPY . .
RUN pip3 install -r requirements.txt
