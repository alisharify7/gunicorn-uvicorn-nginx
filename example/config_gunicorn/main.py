from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World from gunicorn-uvicorn-nginx, test"}
