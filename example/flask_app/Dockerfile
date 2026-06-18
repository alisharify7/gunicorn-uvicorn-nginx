FROM alisharify7/gunicorn-uvicorn-nginx:alpine

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .

# Build and run
# docker build -t flask-example .
# docker run -p 80:80 flask-example
# Test: curl http://localhost/
