# 🚀 Gunicorn, Uvicorn, and Nginx - Docker Deployment Guide

> A production-ready Docker image combining **Nginx**, **Gunicorn**, and **Uvicorn** for deploying scalable Python web applications.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Maintained](https://img.shields.io/badge/maintained%3F-yes-green.svg)]()
[![Docker Image](https://img.shields.io/badge/docker-image-blue?logo=docker)]()

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Examples](#examples)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## 📖 Overview

This project provides a **production-ready Docker image** that seamlessly integrates three powerful tools to deploy Python web applications with exceptional performance and reliability:

### 🔧 Components

| Tool | Role | Purpose |
|------|------|---------|
| **Nginx** | Reverse Proxy | Handles HTTP requests, serves static files, manages connections |
| **Gunicorn** | WSGI App Server | Runs synchronous Python apps (Flask, Django) with worker processes |
| **Uvicorn** | ASGI App Server | Runs asynchronous Python apps (FastAPI, Starlette) with async support |

### ✨ Key Features

✅ **Out-of-the-box Setup** - Zero configuration needed for basic deployment  
✅ **Framework Agnostic** - Supports Flask, Django, FastAPI, Starlette, and more  
✅ **Highly Configurable** - Environment variables for easy customization  
✅ **Production Ready** - Includes security features and performance optimizations  
✅ **Multiple Image Variants** - Full or Alpine for different use cases  
✅ **Gzip Compression** - Automatic response compression  
✅ **Health Checks** - Ready for monitoring and orchestration  

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Request                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ Port 80
                           ↓
                    ┌──────────────┐
                    │    Nginx     │ (Reverse Proxy)
                    │ Load Balancer│
                    └──────┬───────┘
                           │ Port 8000
                           ↓
          ┌────────────────────────────────┐
          │  Gunicorn/Uvicorn Workers      │
          │  (Multiple Process Pool)       │
          └────────────┬───────────────────┘
                       │
                       ↓
           ┌───────────────────────┐
           │  Python Application   │
           │  (FastAPI/Flask/etc)  │
           └───────────────────────┘
```

**Data Flow:**
1. Nginx receives client requests on port 80
2. Nginx forwards requests to Gunicorn/Uvicorn on port 8000
3. Application processes the request
4. Response is sent back through Nginx to the client

---

## ⚡ Quick Start

### Minimal Dockerfile

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

### Create Your Application

**`main.py`** (Required)
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from gunicorn-uvicorn-nginx"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
```

**`requirements.txt`** (Required)
```
fastapi
```

### Build and Run

```bash
# Build
docker build -t my-app .

# Run
docker run -p 8080:80 my-app
```

Visit `http://localhost:8080` 🎉

---

## 📋 Prerequisites

Before using this image, ensure you have:

- ✅ Docker installed (version 20.10+)
- ✅ Python application with `main.py` in project root
- ✅ `requirements.txt` with all dependencies
- ✅ `main.py` exports an `app` variable (ASGI/WSGI compatible)

### Supported Python Frameworks

**Async (ASGI):**
- FastAPI
- Starlette
- Quart
- Sanic

**Sync (WSGI):**
- Flask
- Django
- Pyramid
- Bottle

---

## 🔧 Installation

### Available Docker Tags

| Tag | Base Image | Size | Use Case |
|-----|-----------|------|----------|
| `latest` | nginx:latest | ~500MB | Production (full features) |
| `alpine-latest` | nginx:1.27.3-alpine | ~150MB | Lightweight deployments |
| `1.0.0` | nginx:latest | ~500MB | Specific version |
| `alpine-1.0.0` | nginx:1.27.3-alpine | ~150MB | Specific lightweight version |

### Pull the Image

```bash
# Full-featured image
docker pull alisharify7/gunicorn-uvicorn-nginx:latest

# Lightweight Alpine image
docker pull alisharify7/gunicorn-uvicorn-nginx:alpine-latest
```

---

## ⚙️ Configuration

### Environment Variables

Configure your deployment using environment variables. No need to rebuild!

#### Gunicorn Configuration

| Variable | Default | Type | Description |
|----------|---------|------|-------------|
| `GUNICORN_WORKERS` | 2 | int | Number of worker processes (recommended: 2-4 × CPU cores) |
| `GUNICORN_THREADS` | 4 | int | Threads per worker for async operations |
| `GUNICORN_TIMEOUT` | 120 | int | Worker timeout in seconds (increase for long-running requests) |
| `GUNICORN_BIND_ADDRESS` | 127.0.0.1 | str | Address Gunicorn binds to (use `0.0.0.0` for Docker) |
| `GUNICORN_BIND_PORT` | 8000 | str | Port Gunicorn listens on |
| `GUNICORN_CMD_ARGS` | (auto) | str | Override entire Gunicorn command (advanced) |

#### Python Configuration

| Variable | Value | Purpose |
|----------|-------|---------|
| `PYTHONDONTWRITEBYTECODE` | 1 | Disable Python bytecode (.pyc files) |
| `PYTHONUNBUFFERED` | 1 | Real-time logging output |

#### Other Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `INSTALL_PACKAGES` | (not set) | Set to skip `requirements.txt` installation |

### Configuration Methods

#### Method 1: Using Docker Run (Easiest)

```bash
docker run \
  -e GUNICORN_WORKERS=4 \
  -e GUNICORN_THREADS=8 \
  -e GUNICORN_TIMEOUT=60 \
  -p 8080:80 \
  my-app
```

#### Method 2: Using Environment File

**`.env`**
```env
GUNICORN_WORKERS=4
GUNICORN_THREADS=8
GUNICORN_TIMEOUT=60
```

```bash
docker run --env-file .env -p 8080:80 my-app
```

#### Method 3: Docker Compose (Recommended for Production)

**`docker-compose.yml`**
```yaml
version: '3.8'

services:
  web:
    image: alisharify7/gunicorn-uvicorn-nginx:latest
    ports:
      - "80:80"
    environment:
      GUNICORN_WORKERS: 4
      GUNICORN_THREADS: 8
      GUNICORN_TIMEOUT: 60
    volumes:
      - ./requirements.txt:/app/requirements.txt
      - ./main.py:/app/main.py
    restart: always
```

Run with: `docker-compose up -d`

---

## 📚 Examples

> 🔗 **Full examples available in:** [`example/`](example/) directory

### Example 1: Simple FastAPI App

**Dockerfile**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY main.py .
```

**main.py**
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello, World!"}
```

**Build and run:**
```bash
docker build -t fastapi-app .
docker run -p 8080:80 fastapi-app
```

---

### Example 2: Custom Gunicorn Configuration

**Dockerfile**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest

# Optimize for multi-core systems
ENV GUNICORN_WORKERS=8
ENV GUNICORN_THREADS=4
ENV GUNICORN_TIMEOUT=60
ENV GUNICORN_BIND_ADDRESS=0.0.0.0

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Benefits:**
- 8 worker processes for better throughput
- Lower timeout for faster failure detection
- Accessible from external hosts

---

### Example 3: Custom Nginx Configuration

**Dockerfile**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

COPY custom-nginx.conf /etc/nginx/conf.d/

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**custom-nginx.conf**
```nginx
# Add security headers
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# Enable CORS
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
```

---

### Example 4: Override Full Gunicorn Command

**Dockerfile**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

# Full control over Gunicorn startup
ENV GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --workers 4 \
  --threads 8 \
  --timeout 60 \
  --log-level info \
  --access-logfile - \
  --error-logfile -"

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Note:** When `GUNICORN_CMD_ARGS` is set, all other Gunicorn env vars are ignored.

---

### Example 5: Flask Application

**main.py**
```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return {'message': 'Hello from Flask'}

if __name__ == '__main__':
    app.run(debug=False)
```

**requirements.txt**
```
flask
```

---

## 🚀 Advanced Usage

### Mounting Nginx Configuration

Mount custom Nginx config files without rebuilding:

```bash
docker run \
  -v /path/to/custom.conf:/etc/nginx/conf.d/custom.conf \
  -p 8080:80 \
  my-app
```

### Volume Mounting for Development

```bash
docker run \
  -v $(pwd):/app \
  -p 8080:80 \
  my-app
```

### Health Checks

Add health check to your Dockerfile or docker-compose:

**Dockerfile**
```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

COPY . .
```

**docker-compose.yml**
```yaml
services:
  web:
    image: alisharify7/gunicorn-uvicorn-nginx:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
```

### Running with Docker Swarm

```bash
docker service create \
  --name web-service \
  --publish 80:80 \
  -e GUNICORN_WORKERS=4 \
  alisharify7/gunicorn-uvicorn-nginx:latest
```

### Running with Kubernetes

**deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: alisharify7/gunicorn-uvicorn-nginx:latest
        ports:
        - containerPort: 80
        env:
        - name: GUNICORN_WORKERS
          value: "4"
        - name: GUNICORN_THREADS
          value: "8"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
```

---

## 💡 Best Practices

### 1. Resource Optimization

```dockerfile
# Right sizing workers = better performance
# Formula: workers = (2 × CPU_cores) + 1
# Example for 4-core system:
ENV GUNICORN_WORKERS=9
ENV GUNICORN_THREADS=4
```

### 2. Use Alpine for Production

Alpine images are 70% smaller, perfect for Kubernetes and cloud deployments:

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest
```

### 3. Implement Health Checks

Always add health check endpoints to your app:

```python
@app.get("/health")
def health_check():
    # Check database, cache, etc.
    return {"status": "ok"}
```

### 4. Logging Best Practices

Configure proper logging:

```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.get("/")
def root():
    logger.info("Root endpoint accessed")
    return {"message": "ok"}
```

### 5. Security Headers

Always add security headers via Nginx:

```nginx
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Strict-Transport-Security "max-age=31536000" always;
add_header X-XSS-Protection "1; mode=block" always;
```

### 6. Performance Tuning

```dockerfile
# For high-traffic applications
ENV GUNICORN_WORKERS=16
ENV GUNICORN_THREADS=8
ENV GUNICORN_TIMEOUT=120

# Enable gzip compression (already enabled by default)
# Client body size for uploads
ENV CLIENT_MAX_BODY_SIZE=250M
```

### 7. Non-root User (Recommended)

Add a non-root user in your Dockerfile:

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser
```

---

## 🔐 Security

The image comes with built-in security features:

✅ **Hidden File Protection** - `.` files are blocked  
✅ **Database Protection** - `.sqlite3` files are not served  
✅ **SSL Ready** - `.well-known` paths allowed for certificates  
✅ **Response Compression** - Reduces data exposure  
✅ **Version Hiding** - Nginx version not exposed  

---

## 🔍 Troubleshooting

### Issue: "ModuleNotFoundError"

**Problem:** Dependencies not installed  
**Solution:** Ensure all packages are in `requirements.txt`

```bash
# Rebuild without cache
docker build --no-cache -t my-app .
```

### Issue: Port Already in Use

**Problem:** `docker: Error response from daemon: driver failed`  
**Solution:** Use different port mapping

```bash
docker run -p 8081:80 my-app  # Use 8081 instead
```

### Issue: Application Timeout

**Problem:** Requests timing out  
**Solution:** Increase timeout

```bash
docker run -e GUNICORN_TIMEOUT=300 -p 8080:80 my-app
```

### Issue: Out of Memory

**Problem:** Application crashes under load  
**Solution:** Increase Docker memory limit

```bash
docker run -m 2gb -p 8080:80 my-app
```

### Issue: 502 Bad Gateway

**Problem:** Nginx can't reach Gunicorn  
**Solution:** Check logs

```bash
docker logs <container_id>
```

---

## 📊 Monitoring

### Logs Location

| Log File | Path | Purpose |
|----------|------|---------|
| Nginx Access | `/var/log/nginx/access.log` | HTTP request logs |
| Nginx Error | `/var/log/nginx/error.log` | Nginx errors |
| Gunicorn Output | stdout | Application logs |

### View Logs

```bash
# Follow logs in real-time
docker logs -f <container_id>

# View last 100 lines
docker logs --tail 100 <container_id>

# Access inside container
docker exec -it <container_id> tail -f /var/log/nginx/access.log
```

### Log Format (Nginx)

```
REQUEST_METHOD HTTP_STATUS CLIENT_IP "REQUEST_URI" "REFERER" "USER_AGENT"
```

Example:
```
GET 200 192.168.1.100 "/api/users" "-" "Mozilla/5.0..."
```

---

## 📝 Project Structure

```
your-project/
├── main.py                 # ⭐ REQUIRED - Application entry point
├── requirements.txt        # ⭐ REQUIRED - Python dependencies
├── Dockerfile             # Build configuration
├── docker-compose.yml     # Optional - Orchestration
└── custom-nginx.conf      # Optional - Custom Nginx config
```

### Required Files

#### `main.py`
```python
from fastapi import FastAPI

app = FastAPI()  # ⭐ Must export 'app' variable

@app.get("/")
def read_root():
    return {"message": "Hello"}
```

#### `requirements.txt`
```
fastapi
uvicorn[standard]
requests
```

---

## 🌐 Supported Frameworks

### FastAPI (Recommended for new projects)
```python
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello"}
```

### Flask
```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return {"message": "Hello"}
```

### Django
```python
# wsgi.py or similar
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
app = get_wsgi_application()
```

### Starlette
```python
from starlette.applications import Starlette
from starlette.responses import JSONResponse

app = Starlette()

@app.route("/", methods=["GET"])
async def homepage(request):
    return JSONResponse({"message": "Hello"})
```

---

## 🐳 Docker & Docker Compose

### Docker Compose Example (Production-Ready)

**`docker-compose.yml`**
```yaml
version: '3.8'

services:
  web:
    image: alisharify7/gunicorn-uvicorn-nginx:latest
    container_name: my-web-app
    ports:
      - "80:80"
    environment:
      GUNICORN_WORKERS: 4
      GUNICORN_THREADS: 8
      GUNICORN_TIMEOUT: 120
      PYTHONUNBUFFERED: 1
    volumes:
      - ./custom-nginx.conf:/etc/nginx/conf.d/custom.conf:ro
      - app-logs:/var/log/nginx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    restart: unless-stopped
    networks:
      - web-network

networks:
  web-network:
    driver: bridge

volumes:
  app-logs:
    driver: local
```

Run with:
```bash
docker-compose up -d
docker-compose logs -f
docker-compose down
```

---

## ⚡ Performance Tips

### 1. Choose the Right Image

- **Full Image** (`latest`) - More features, ~500MB
- **Alpine** (`alpine-latest`) - Lightweight, ~150MB

```dockerfile
# For production/cloud deployments
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest
```

### 2. CPU Cores Optimization

```bash
# Check CPU cores
docker run my-app nproc

# Set workers accordingly
# Formula: (2 × cores) + 1 for IO-bound
#         cores for CPU-bound
```

### 3. Memory Optimization

```bash
# Monitor memory usage
docker stats <container_id>

# Limit memory in docker-compose
services:
  web:
    image: my-app:latest
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### 4. Caching Strategy

```nginx
# In custom-nginx.conf
# Cache static assets for 30 days
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

---

### Issues & Feedback

Found a bug or have a suggestion? Please open an issue on GitHub:
https://github.com/alisharify7/gunicorn-uvicorn-nginx/issues

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📊 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=alisharify7/gunicorn-uvicorn-nginx&type=Date)](https://star-history.com/#alisharify7/gunicorn-uvicorn-nginx&Date)

---

## 📄 License

This project is licensed under the **GPL-3.0 License** - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Ali Sharifi** (@alisharify7)  
📧 Email: alisharifyofficial@gmail.com  
🔗 GitHub: https://github.com/alisharify7

---

**Made with ❤️ for the Python community**