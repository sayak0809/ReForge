from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import users
from app.routes import xp
from app.routes import weight
from app.routes import quests
from app.routes import food
from app.routes import coach

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
