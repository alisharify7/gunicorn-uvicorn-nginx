FROM nginx:alpine

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1


COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./custom.conf /etc/nginx/conf.d/custom.conf

WORKDIR /app

COPY . .
COPY requirements.txt .
COPY start.sh .

RUN echo "nameserver: 8.8.8.8\nnameserver: 8.8.4.4" > /etc/resolve.conf

RUN apk update && apk add --no-cache python3 py3-pip \
    && pip3 config set global.break-system-packages true \
    && pip3 install --no-cache-dir gunicorn uvicorn \
    && pip3 install --no-cache-dir -r requirements.txt


#TODO: create a non-root user

EXPOSE 80

RUN chmod +x start.sh

CMD ["sh", "start.sh"]