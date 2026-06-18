# Project Map: Gunicorn, Uvicorn, and Nginx

## 📋 Project Overview

**Repository:** alisharify7/gunicorn-uvicorn-nginx  
**Purpose:** Docker-based solution for deploying Python web applications using Nginx as a reverse proxy with Gunicorn/Uvicorn application servers.  
**License:** GPL-3.0  
**Author:** Ali Sharifi (@alisharify7)  
**Email:** alisharifyofficial@gmail.com  

## 🎯 Project Goals

- Provide a production-ready Docker image for deploying Python web apps
- Support both synchronous (Flask, Django) and asynchronous (FastAPI, Starlette) frameworks
- Combine Nginx (reverse proxy), Gunicorn/Uvicorn (application servers) for scalability and performance
- Simplify deployment with configurable environment variables
- Support custom Nginx configurations through mounted config files

## 🏗️ Architecture

```
Client Request
    ↓
Nginx (Port 80 - Reverse Proxy)
    ↓
Gunicorn/Uvicorn Workers (Port 8000 - Default)
    ↓
Python Application (main:app)
```

### Key Components

| Component | Purpose | Default Port |
|-----------|---------|--------------|
| **Nginx** | Reverse proxy, static file serving, load balancing | 80 |
| **Gunicorn** | WSGI server for sync frameworks (Flask, Django) | 8000 |
| **Uvicorn** | ASGI server for async frameworks (FastAPI, Starlette) | 8000 |
| **Python App** | User's FastAPI/Flask/Django application | - |

## 📁 Directory Structure

```
gunicorn-uvicorn-nginx/
├── LICENSE                          # GPL-3.0 License
├── README.md                        # Main documentation
├── .gitignore                       # Python/Docker git exclusions
├── PROJECT_MAP.md                   # This file
│
├── docs/
│   └── flow.png                     # Architecture diagram
│
├── docker/                          # Docker image definitions
│   ├── main/                        # Production Docker image (latest Ubuntu)
│   │   ├── Dockerfile              # Main Docker image specification
│   │   ├── start.sh                # Container startup script
│   │   ├── nginx.conf              # Nginx configuration
│   │   ├── custom.conf             # Nginx custom location configs
│   │   ├── main.py                 # Example FastAPI app
│   │   └── requirements.txt        # Example dependencies (pip, fastapi)
│   │
│   ├── alpine/                      # Lightweight Docker image
│   │   ├── Dockerfile              # Alpine-based image (1.27.3-alpine)
│   │   ├── start.sh                # Container startup script
│   │   ├── nginx.conf              # Nginx configuration
│   │   ├── custom.conf             # Nginx custom location configs
│   │   ├── main.py                 # Example FastAPI app
│   │   └── requirements.txt        # Example dependencies
│   │
│   └── __build__/                  # Build artifacts (git-ignored)
│
└── example/                         # Usage examples
    ├── simple/                      # Minimal FastAPI example
    │   ├── Dockerfile              # Simple example Dockerfile
    │   ├── main.py                 # Basic FastAPI app with /endpoint
    │   └── requirements.txt        # Minimal dependencies (fastapi)
    │
    ├── config_gunicorn/            # Gunicorn configuration example
    │   ├── Dockerfile              # Shows Gunicorn env var configuration
    │   ├── main.py                 # Example app
    │   └── requirements.txt        # Example dependencies
    │
    └── config_nginx/               # Nginx configuration example
        ├── Dockerfile              # Shows Nginx config mounting
        ├── add_header.conf         # Custom Nginx header configuration
        ├── main.py                 # Example app
        └── requirements.txt        # Example dependencies
```

## 🐳 Docker Images

### Main Image (`docker/main/`)
- **Base:** `nginx:latest`
- **Build:** Standard Ubuntu/Debian-based
- **Features:** Full feature set, larger image size
- **Use Case:** Production environments where size is not a concern

**Dockerfile Highlights:**
```dockerfile
FROM nginx:latest
ENV GUNICORN_WORKERS 2
ENV GUNICORN_THREADS 4
ENV GUNICORN_TIMEOUT 120
# Installs python3, pip, gunicorn, uvicorn, pyfiglet
# Copies app files and requirements.txt
EXPOSE 80
CMD ["sh", "start.sh"]
```

### Alpine Image (`docker/alpine/`)
- **Base:** `nginx:1.27.3-alpine`
- **Build:** Alpine Linux (minimal)
- **Features:** Lightweight, optimized for size
- **Use Case:** Container environments with resource constraints

**Dockerfile Highlights:**
```dockerfile
FROM nginx:1.27.3-alpine
# Uses apk for package management
# Installs python3, py3-pip, gunicorn, uvicorn, pyfiglet
# Copies app files and requirements.txt
EXPOSE 80
CMD ["sh", "/opt/start.sh"]
```

## 🔧 Configuration

### Environment Variables (Gunicorn)

| Variable | Default | Type | Description |
|----------|---------|------|-------------|
| `GUNICORN_WORKERS` | 2 | int | Number of Gunicorn worker processes |
| `GUNICORN_THREADS` | 4 | int | Number of threads per worker |
| `GUNICORN_TIMEOUT` | 120 | int | Worker timeout in seconds |
| `GUNICORN_BIND_ADDRESS` | 127.0.0.1 | str | Address Gunicorn binds to |
| `GUNICORN_BIND_PORT` | 8000 | str | Port Gunicorn listens on |
| `GUNICORN_CMD_ARGS` | (auto-generated) | str | Full Gunicorn command arguments (overrides all other settings) |
| `PYTHONDONTWRITEBYTECODE` | 1 | - | Python bytecode caching disabled |
| `PYTHONUNBUFFERED` | 1 | - | Python output buffering disabled |

### Nginx Configuration

**Mount Point:** `/etc/nginx/conf.d/` (inside container)

**Default Configuration Files:**
- `nginx.conf` - Main Nginx configuration (worker processes, logging, etc.)
- `custom.conf` - Location-specific configurations (proxy settings, gzip, etc.)

**Key Features in custom.conf:**
- `client_max_body_size 250M` - Maximum request body size
- `gzip on` - Response compression enabled
- `proxy_pass` - Forwards requests to Gunicorn/Uvicorn on configurable address:port
- `X-Forwarded-*` headers - Preserves client information
- `.sqlite3` file blocking - Security: prevents direct DB access
- `.well-known` path exclusion - Certbot/ACME challenge support

## 📦 Key Files

### Startup Script (`start.sh`)

**Purpose:** Initializes and starts both Nginx and Gunicorn services

**Key Operations:**
1. Installs Python dependencies (if `INSTALL_PACKAGES` not set)
2. Displays ASCII art banner using pyfiglet
3. Sets Gunicorn configuration from environment variables
4. Replaces placeholder addresses/ports in Nginx config
5. Starts Nginx in background mode (`daemon off;`)
6. Starts Gunicorn as primary process

**Configuration Details:**
- Resolves environment variable placeholders: `${GUNICORN_BIND_ADDRESS}`, `${GUNICORN_BIND_PORT}`
- Prints Gunicorn configuration on startup
- Allows full override via `GUNICORN_CMD_ARGS`

### Application Requirements

**From `/docker/main/requirements.txt`:**
```
pip
fastapi
```

**From `/example/simple/requirements.txt`:**
```
fastapi
```

**From `/example/config_gunicorn/requirements.txt`:**
```
fastapi
ipython       # test dependency
flask-captcha2  # test dependency
py-smtper     # test dependency
django        # test dependency
```

## 🚀 Usage Examples

### Example 1: Simple Dockerfile (Recommended Starting Point)

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Requirements:** Root project must have:
- `main.py` - Application entry point with `app` variable defined
- `requirements.txt` - Python dependencies

### Example 2: Custom Gunicorn Configuration

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest

# Override Gunicorn settings
ENV GUNICORN_WORKERS 4
ENV GUNICORN_THREADS 4
ENV GUNICORN_TIMEOUT 60
ENV GUNICORN_BIND_PORT 6565
ENV GUNICORN_BIND_ADDRESS 0.0.0.0

# Alternative: Override entire command
# ENV GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker --bind 127.0.0.1 --workers 2 --threads 2 --timeout 55 --log-level=info"

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

### Example 3: Custom Nginx Configuration

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:alpine-latest

# Mount custom Nginx configuration
COPY add_header.conf /etc/nginx/conf.d/

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Custom Nginx Config Example (`add_header.conf`):**
```nginx
add_header X-Custom-Header "value";
add_header Strict-Transport-Security "max-age=31536000" always;
```

## 📋 Example Applications

### 1. Simple Example (`example/simple/`)

**Purpose:** Minimal working example

**Files:**
- `Dockerfile` - Basic Docker setup
- `main.py` - Single endpoint FastAPI app
- `requirements.txt` - FastAPI only

**App Code:**
```python
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World from gunicorn-uvicorn-nginx, test"}
```

### 2. Gunicorn Configuration Example (`example/config_gunicorn/`)

**Purpose:** Demonstrates Gunicorn configuration via environment variables

**Key Feature:** Sets custom worker count, thread count, timeout, and bind port

### 3. Nginx Configuration Example (`example/config_nginx/`)

**Purpose:** Demonstrates custom Nginx configuration

**File:** `add_header.conf` - Custom HTTP headers

## 🔐 Security Features

1. **Root File Protection**
   - Hidden files (starting with `.`) are blocked via Nginx
   - Location: `location ~ /\. { deny all; }`

2. **Database Protection**
   - SQLite3 files are not served via HTTP
   - Location: `location ~\.sqlite3$ { deny all; }`

3. **ACME Challenge Support**
   - `.well-known` path is allowed for SSL certificate provisioning
   - Location: `location ~ /\.well-known { allow all; }`

4. **Response Compression**
   - Gzip compression enabled for common text types
   - Minimum 1024 bytes for compression

5. **Disabled Nginx Version Tokens**
   - `server_tokens off;` - Hides Nginx version in responses

6. **TODO Items:**
   - Create dedicated non-root user for running application services

## 📝 Application Requirements

### Required Files
- **`main.py`** - Application file with `app` variable
  ```python
  from fastapi import FastAPI
  app = FastAPI()
  ```
- **`requirements.txt`** - Python dependencies (one per line)

### Supported Frameworks
- **Synchronous:** Flask, Django (uses Gunicorn)
- **Asynchronous:** FastAPI, Starlette (uses Uvicorn workers)

### Entry Point
- Format: `main:app` (file module and application variable)
- Gunicorn command: `gunicorn main:app ${GUNICORN_CMD_ARGS}`

## 🛠️ Customization Options

### 1. Gunicorn Configuration

**Method 1: Environment Variables**
```bash
docker run -e GUNICORN_WORKERS=4 -e GUNICORN_THREADS=8 ...
```

**Method 2: Full Command Override**
```dockerfile
ENV GUNICORN_CMD_ARGS="-k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --workers 2 --threads 4 --timeout 120"
```

### 2. Nginx Configuration

**Mount custom config file:**
```bash
docker run -v /path/to/nginx.conf:/etc/nginx/conf.d/custom.conf ...
```

Or in Dockerfile:
```dockerfile
COPY custom-nginx.conf /etc/nginx/conf.d/
```

### 3. Environment Variables

**Disable automatic pip install:**
```dockerfile
ENV INSTALL_PACKAGES=true
```

### 4. Python Configuration

**Control output buffering:**
```dockerfile
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
```

## 📊 Startup Flow

```
1. Container starts
2. start.sh executes
3. Install Python dependencies (if needed)
4. Display ASCII banner
5. Export Gunicorn environment variables
6. Substitute placeholders in nginx config
7. Start Nginx (background mode)
8. Start Gunicorn (foreground process)
9. Application running and ready for requests
```

## 🔍 Monitoring & Logs

### Log Files (Inside Container)

| Log | Path | Purpose |
|-----|------|---------|
| Nginx Access | `/var/log/nginx/access.log` | HTTP request log |
| Nginx Error | `/var/log/nginx/error.log` | Nginx errors |
| Gunicorn | stdout (attached to container) | Application output |

### Log Format

**Nginx Access Log:**
```
$request_method $status $http_x_forwarded_for "$request_uri" "$http_referer" "$http_user_agent"
```

Example:
```
GET 200 192.168.1.1 "/api/endpoint" "-" "Mozilla/5.0..."
```

## 🚦 Ports

- **Port 80:** Nginx (public-facing)
- **Port 8000:** Gunicorn/Uvicorn (internal, listening address configurable)
- **Port 127.0.0.1:8000:** Default Gunicorn bind (internal only)

## ✅ Pre-deployment Checklist

- [ ] Create `main.py` with `app` variable
- [ ] Create `requirements.txt` with all dependencies
- [ ] Test application locally with `uvicorn main:app`
- [ ] Verify dependencies are correctly listed
- [ ] Configure environment variables as needed
- [ ] Set appropriate worker count based on CPU cores
- [ ] Configure timeout for application needs
- [ ] Test Nginx configuration if customizing
- [ ] Verify no sensitive data in Dockerfile or git history

## 📚 Related Documentation

- **Gunicorn Docs:** https://docs.gunicorn.org/
- **Uvicorn Docs:** https://www.uvicorn.org/
- **Nginx Docs:** https://nginx.org/
- **FastAPI Docs:** https://fastapi.tiangolo.com/
- **Docker Docs:** https://docs.docker.com/

## 🐛 Known Issues & TODOs

1. **Non-root User:** Currently runs as root. TODO: Create dedicated user
2. **More Examples:** README indicates "TODO: add more examples"

## 💡 Best Practices

1. **Use Alpine images** for smaller deployments
2. **Set appropriate worker count** = 2-4 × CPU cores
3. **Configure timeout** based on application response time (default 120s)
4. **Use custom nginx.conf** for production headers and security
5. **Mount volumes** for logs and persistent data
6. **Use environment variables** for configuration over rebuilding images
7. **Implement health checks** in your application (`/health` endpoint)
8. **Monitor memory and CPU** usage per worker

## 📄 Repository Structure Summary

| Path | Type | Purpose |
|------|------|---------|
| `docker/main/` | Dir | Production image definition |
| `docker/alpine/` | Dir | Lightweight image definition |
| `example/simple/` | Dir | Minimal usage example |
| `example/config_gunicorn/` | Dir | Gunicorn config example |
| `example/config_nginx/` | Dir | Nginx config example |
| `docs/flow.png` | Image | Architecture diagram |
| `README.md` | Doc | Main documentation |
| `LICENSE` | File | GPL-3.0 license text |
| `.gitignore` | Config | Git exclusions |

---

**Last Updated:** 2026-06-18  
**Project Status:** Active  
**Maintainer:** Ali Sharifi (@alisharify7)
