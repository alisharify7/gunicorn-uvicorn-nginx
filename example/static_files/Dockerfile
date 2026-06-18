FROM alisharify7/gunicorn-uvicorn-nginx:latest

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .

# Build and run
# docker build -t static-files-example .
# docker run -p 80:80 static-files-example
# Test: open http://localhost in browser
