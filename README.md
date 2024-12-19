# gunicorn-uvicorn-nginx

<img src="https://images.mirror-media.xyz/publication-images/7aStlV9clT-Ff611h53d-.png">
<img src="https://ucarecdn.com/068cfc2b-7fda-4fcd-afba-f2da0de591b5/-/resize/700/">

### Gunicorn, Uvicorn, and Nginx are often used together in Python web application deployments to ensure efficiency, scalability, and robustness. Here's what each component does:

## 🚧 How to Use

    docker pull ...
    not implemented yet


### 🦄 1.0 Gunicorn:

Gunicorn (Green Unicorn) is a WSGI (Web Server Gateway Interface) server for Python web applications.
It acts as a multi-threaded HTTP server that handles requests and passes them to the Python application.
It's suitable for synchronous Python web frameworks like Flask or Django.
Gunicorn works by serving multiple worker processes to handle multiple requests simultaneously.

### 🦄 2.0 Uvicorn:

Uvicorn is an ASGI (Asynchronous Server Gateway Interface) server, designed to handle asynchronous web frameworks like FastAPI or Starlette.
It is ideal for handling long-lived connections and HTTP/2, WebSockets, or other asynchronous protocols, making it more efficient than WSGI servers for certain applications.
Uvicorn is often used for asynchronous Python web frameworks that require a high degree of concurrency.

### 🌐 3.0 Nginx:

Nginx is a reverse proxy server and web server. It sits in front of your application server (like Gunicorn or Uvicorn) and handles incoming HTTP requests.
It serves static files directly (like images, CSS, JavaScript), which reduces the load on your application server.
Nginx also acts as a load balancer, distributing incoming traffic to multiple instances of Gunicorn or Uvicorn, improving scalability.
It can handle SSL termination, security configurations, and other tasks that improve the overall performance and security of the application.
How They Work Together:
Nginx sits at the front, receiving HTTP requests.
It forwards requests to Gunicorn (for WSGI apps) or Uvicorn (for ASGI apps), which in turn processes the request with the Python application.
Gunicorn or Uvicorn processes the request, performs the necessary logic, and then sends the response back to Nginx, which returns the response to the client.
This combination allows you to:

Handle both synchronous and asynchronous web applications efficiently.
Serve static content (images, files) directly through Nginx.
Scale your application through multiple worker processes (Gunicorn/Uvicorn).
Ensure high availability and load balancing.

## 🔨 Configuration:

for configuring the nginx you can simply mount a nginx.conf file into and it will
automatically will be added inside the server block

```bash
/etc/nginx/conf.d/
```

and automatically it will apply by nginx.
for configuring the gunicorn environment config map (read here https://docs.gunicorn.org/en/latest/configure.html)
but for some base config you can use following configurations

| key                     | default value                                                                                                                                               | value type | description                                 |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|---------------------------------------------|
| `GUNICORN_WORKERS`      | 2                                                                                                                                                           | int        | number of the gunicorn worker               |
| `GUNICORN_THREADS`      | 4                                                                                                                                                           | int        | number of the gunicorn threads              |
| `GUNICORN_TIMEOUT`      | 120                                                                                                                                                         | int        | gunicorn timeout                            | 
| `GUNICORN_BIND_ADDRESS` | 127.0.0.1                                                                                                                                                   | str        | gunicorn bind address                       | 
| `GUNICORN_BIND_PORT`    | 8000                                                                                                                                                        | str        | gunicorn bind port                          | 
| `GUNICORN_CMD_ARGS`     | ```bash"-k uvicorn.workers.UvicornWorker --bind ${GUNICORN_BIND} --workers ${GUNICORN_WORKERS} --threads ${GUNICORN_THREADS} --timeout ${GUNICORN_TIMEOUT}"``` | str        | arg command that gunicorn takes for running | 

