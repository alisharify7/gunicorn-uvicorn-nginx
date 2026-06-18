"""
FastAPI example with database and API endpoints
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List

app = FastAPI(title="FastAPI Example")

# Sample database (in-memory)
users_db = []

class User(BaseModel):
    id: int
    name: str
    email: str

@app.get("/")
def read_root():
    return {"message": "FastAPI app running on gunicorn-uvicorn-nginx"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/users", response_model=List[User])
def get_users():
    return users_db

@app.post("/users", response_model=User)
def create_user(user: User):
    users_db.append(user)
    return user

@app.get("/users/{user_id}", response_model=User)
def get_user(user_id: int):
    for user in users_db:
        if user.id == user_id:
            return user
    raise HTTPException(status_code=404, detail="User not found")

@app.delete("/users/{user_id}")
def delete_user(user_id: int):
    for i, user in enumerate(users_db):
        if user.id == user_id:
            users_db.pop(i)
            return {"message": "User deleted"}
    raise HTTPException(status_code=404, detail="User not found")
