import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.routes import users
from app.routes import xp
from app.routes import weight
from app.routes import quests
from app.routes import food
from app.routes import coach
from app.database import engine, Base
from app.models import User, WeightLog, Quest, UserQuest, FoodLog, FoodLogImage, XPEvent, CoachMessage  # noqa: F401

app = FastAPI(
    title="Reforge API",
    description="AI-powered fitness RPG backend",
    version="0.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router)
app.include_router(xp.router)
app.include_router(weight.router)
app.include_router(quests.router)
app.include_router(food.router)
app.include_router(coach.router)

@app.get("/")
def root():
    return {"message": "Reforge API is running 🔥"}

@app.get("/health")
def health():
    return {"status": "ok"}

# Temporary one-time setup endpoint — remove after tables are created on the
# deployed database. Guarded by SECRET_KEY so it's not a fully open DB-mutating
# endpoint on the public URL.
@app.post("/_setup/create-tables")
def setup_create_tables(token: str):
    if not token or token != os.getenv("SECRET_KEY"):
        raise HTTPException(status_code=403, detail="Invalid token")
    Base.metadata.create_all(bind=engine)
    return {"created": True}
