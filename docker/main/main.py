from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World from gunicorn-uvicorn-nginx", "msg": "test application, if you seeing this that means your not configure your dockerfile correctly."}
