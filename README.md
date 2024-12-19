# gunicorn-uvicorn-nginx

<img src="https://images.mirror-media.xyz/publication-images/7aStlV9clT-Ff611h53d-.png">
<img src="https://ucarecdn.com/068cfc2b-7fda-4fcd-afba-f2da0de591b5/-/resize/700/">

# Gunicorn, Uvicorn, and Nginx

These tools are commonly used together to deploy Python web apps efficiently and reliably:


<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Gunicorn_logo_2010.svg/1024px-Gunicorn_logo_2010.svg.png" style="width: 30%">

    A WSGI server for synchronous frameworks (e.g., Flask, Django).
    Handles multiple HTTP requests with worker processes.

<img src="https://www.uvicorn.org/uvicorn.png" style="width: 15%">

    An ASGI server for asynchronous frameworks (e.g., FastAPI, Starlette).
    Ideal for real-time features like WebSockets and high-concurrency apps.

<img src="https://upload.wikimedia.org/wikipedia/commons/c/c5/Nginx_logo.svg" style="width: 25%">

    A reverse proxy that handles HTTP requests, serves static files, and balances traffic between Gunicorn or Uvicorn instances.
    Improves scalability, security, and performance.

## ❓ How it works:
Nginx forwards requests to Gunicorn/Uvicorn, which process the logic and send responses back through Nginx to the client.



## 🚧 How to Use

    docker pull ...
    not implemented yet

🛑 The root of your project should contain a file named `main.py` and another named `requirements.txt` (dependencies list). 🛑 


## 🔨 Configuration:

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

#### example:
```dockerfile
FROM  alisharify7/gunicorn-uvicorn-nginx:1.0.0

WORKDIR /app
ENV GUNICORN_CMD_ARGS '-k uvicorn.workers.UvicornWorker --log-level=debug'
# this will be following command inside the container 
# gunicorn main:app -k uvicorn.workers.UvicornWorker --log-level=debug

COPY . .
COPY requirements.txt .
```
