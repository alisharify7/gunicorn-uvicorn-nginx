"""
FastAPI app serving static files
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI()

@app.get("/api/health")
def health():
    return {"status": "healthy"}

# Mount static files directory
if os.path.exists("static"):
    app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def serve_index():
    with open("static/index.html", "r") as f:
        return f.read()
