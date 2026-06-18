# Examples

This directory contains practical examples of using the `gunicorn-uvicorn-nginx` Docker image.

## 📁 Available Examples

### 1. **simple** - Basic FastAPI App
Minimal example to get started quickly.
```bash
cd simple
docker build -t gunicorn-example .
docker run -p 80:80 gunicorn-example
curl http://localhost
```

### 2. **fastapi_app** - FastAPI with REST API
Full-featured REST API with CRUD operations for users.
- Multiple endpoints (GET, POST, DELETE)
- Request validation with Pydantic
- Configured with 4 workers for better performance

```bash
cd fastapi_app
docker build -t fastapi-example .
docker run -p 80:80 fastapi-example
# Open http://localhost/docs for interactive API documentation
```

**Test endpoints:**
```bash
# Create user
curl -X POST http://localhost/users \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "name": "John", "email": "john@example.com"}'

# Get all users
curl http://localhost/users

# Delete user
curl -X DELETE http://localhost/users/1
```

### 3. **flask_app** - Flask Application
Task management API built with Flask.
- Simple task CRUD operations
- Uses Alpine Linux for smaller image size
- Perfect for lightweight applications

```bash
cd flask_app
docker build -t flask-example .
docker run -p 80:80 flask-example
```

**Test endpoints:**
```bash
# Create task
curl -X POST http://localhost/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries"}'

# Get tasks
curl http://localhost/tasks

# Update task
curl -X PUT http://localhost/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"done": true}'
```

### 4. **config_gunicorn** - Gunicorn Configuration
Example showing custom Gunicorn settings via environment variables.
- Configure workers, threads, and timeout
- Customize bind address and port
- Override with custom Gunicorn command

```bash
cd config_gunicorn
docker build -t gunicorn-config .
docker run -p 80:80 gunicorn-config
```

### 5. **config_nginx** - Nginx Configuration
Example showing custom Nginx settings.
- Mount custom Nginx config files
- Add custom headers
- Modify proxy settings

```bash
cd config_nginx
docker build -t nginx-config .
docker run -p 80:80 nginx-config
```

### 6. **static_files** - Serving Static Files
FastAPI app with HTML/CSS/JS static file serving.
- Serve HTML pages
- Combine static files with API routes
- Perfect for Single Page Applications (SPAs)

```bash
cd static_files
docker build -t static-example .
docker run -p 80:80 static-example
# Open http://localhost in browser
```

---

## 🚀 Quick Start Template

Use this as a template for your own projects:

```dockerfile
FROM alisharify7/gunicorn-uvicorn-nginx:latest

# Configure Gunicorn (optional)
ENV GUNICORN_WORKERS=4
ENV GUNICORN_THREADS=8
ENV GUNICORN_TIMEOUT=60

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
```

**Requirements:**
- Your project must have `main.py` with an `app` object
- Include a `requirements.txt` with dependencies

---

## 📊 Comparison

| Example | Framework | Use Case | Size |
|---------|-----------|----------|------|
| simple | FastAPI | Quick start | Minimal |
| fastapi_app | FastAPI | Full REST API | Small |
| flask_app | Flask | Lightweight API | Very Small |
| static_files | FastAPI | Web + API | Small |
| config_gunicorn | FastAPI | Performance tuning | Minimal |
| config_nginx | FastAPI | Nginx customization | Minimal |

---

## 🔗 Image Variants

- `alisharify7/gunicorn-uvicorn-nginx:latest` - Ubuntu-based (larger)
- `alisharify7/gunicorn-uvicorn-nginx:alpine` - Alpine Linux (smaller, faster)

**Recommendation:** Use Alpine for production deployments.

---

## 📚 Learn More

- [Gunicorn Docs](https://docs.gunicorn.org/)
- [Uvicorn Docs](https://www.uvicorn.org/)
- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Flask Docs](https://flask.palletsprojects.com/)
