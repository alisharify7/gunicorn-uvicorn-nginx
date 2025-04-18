"""
* gunicorn-uvicorn-nginx
* author: @alisharify7
* email: alisharifyofficial@gmail.com
* Copyright (c) 2025 - ali sharifi
* license: see LICENSE for more details.
* https://github.com/alisharify7/gunicorn-uvicorn-nginx
"""

from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World from gunicorn-uvicorn-nginx", "msg": "test application, if you seeing this that means your not configure your dockerfile correctly."}
