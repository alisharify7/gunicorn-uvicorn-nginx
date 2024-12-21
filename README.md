# Gunicorn, Uvicorn, and Nginx

These tools are commonly used together to deploy Python web apps efficiently and reliably:

<img src="https://raw.githubusercontent.com/free-programmers/gunicorn-uvicorn-nginx/refs/heads/main/docs/flow.png">

 ** all examples are in <a href="https://github.com/free-programmers/gunicorn-uvicorn-nginx/tree/main/example">here</a> **

## Gunicorn
    A WSGI server for synchronous frameworks (e.g., Flask, Django).
    Handles multiple HTTP requests with worker processes.

## Uvicorn
    An ASGI server for asynchronous frameworks (e.g., FastAPI, Starlette).
    Ideal for real-time features like WebSockets and high-concurrency apps.

## Nginx
    A reverse proxy that handles HTTP requests, serves static files, and balances traffic between Gunicorn or Uvicorn instances.
    Improves scalability, security, and performance.

## ❓ How it works:
Nginx forwards requests to Gunicorn/Uvicorn, which process the logic and send responses back through Nginx to the client.


## 🚧 How to Use in Dockerfile
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx: tag or latest
```

🛑 The root of your project should contain a file named `main.py` and another named `requirements.txt` (dependencies list). 🛑 


## 🔨 how config each component:

## Nginx
for configuring the **--nginx--** you can simply mount a nginx.conf file into ```/etc/nginx/conf.d/``` and it will
automatically will be added inside the server block.

```bash
server {
    listen       80;
    server_name  localhost;
    root         /app;
    
    # your config goes here
}
```
## Gunicorn 
for configuring the **gunicorn** use environment config map (read here https://docs.gunicorn.org/en/latest/configure.html)
### available config mappers: 

| key                     | default value                                                                                                                                               | value type | description                                 |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|---------------------------------------------|
| `GUNICORN_WORKERS`      | 2                                                                                                                                                           | int        | number of the gunicorn worker               |
| `GUNICORN_THREADS`      | 4                                                                                                                                                           | int        | number of the gunicorn threads              |
| `GUNICORN_TIMEOUT`      | 120                                                                                                                                                         | int        | gunicorn timeout                            | 
| `GUNICORN_BIND_ADDRESS` | 127.0.0.1                                                                                                                                                   | str        | gunicorn bind address                       | 
| `GUNICORN_BIND_PORT`    | 8000                                                                                                                                                        | str        | gunicorn bind port                          | 
| `GUNICORN_CMD_ARGS`     | ```bash"-k uvicorn.workers.UvicornWorker --bind ${GUNICORN_BIND} --workers ${GUNICORN_WORKERS} --threads ${GUNICORN_THREADS} --timeout ${GUNICORN_TIMEOUT}"``` | str        | arg command that gunicorn takes for running | 

### if you want to gunicorn uses your starter command instead of the default starter command (``GUNICORN_CMD_ARGS``), you can simply override the (``GUNICORN_CMD_ARGS``) env. 
```bash
exec gunicorn main:app ${GUNICORN_CMD_ARGS} # your command will be replaced here
```

# examples

### basic:
```dockerfile
FROM  alisharify7/gunicorn-uvicorn-nginx:1.0.0

WORKDIR /app
ENV GUNICORN_CMD_ARGS '-k uvicorn.workers.UvicornWorker --log-level=debug'
# this will be following command inside the container 
# gunicorn main:app -k uvicorn.workers.UvicornWorker --log-level=debug

COPY . .
COPY requirements.txt .
```

### gunicorn config option:
```dockerfile
FROM  alisharify7/gunicorn-uvicorn-nginx:alpine-1.0.0

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
COPY requirements.txt .
COPY . .
```
### nginx config:
```dockerfile
FROM  alisharify7/gunicorn-uvicorn-nginx:alpine-1.0.0

COPY add_header.conf /etc/nginx/conf.d/

WORKDIR /app
COPY requirements.txt .
COPY . .
```
