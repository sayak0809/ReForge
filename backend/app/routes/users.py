from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, WeightLog, XPEvent
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/users", tags=["users"])

class UserCreate(BaseModel):
    name: str
    age: int
    height_cm: float
    current_weight: float
    goal_weight: float

class UserUpdate(BaseModel):
    name: str | None = None
    age: int | None = None
    height_cm: float | None = None
    current_weight: float | None = None
    goal_weight: float | None = None

class UserResponse(BaseModel):
    id: int
    name: str
    age: int
    height_cm: float
    current_weight: float
    goal_weight: float
    xp: int
    level: int
    title: str

    class Config:
        from_attributes = True

@router.post("/", response_model=UserResponse)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(**user.model_dump())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    weight_log = WeightLog(user_id=db_user.id, weight=user.current_weight)
    db.add(weight_log)
    db.commit()

    return db_user

@router.get("/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.patch("/{user_id}", response_model=UserResponse)
def update_user(user_id: int, update: UserUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    changes = update.model_dump(exclude_unset=True)
    weight_changed = "current_weight" in changes and changes["current_weight"] != user.current_weight
    for field, value in changes.items():
        setattr(user, field, value)

    if weight_changed:
        db.add(WeightLog(user_id=user.id, weight=user.current_weight))

    db.commit()
    db.refresh(user)
    return user

@router.post("/{user_id}/photo")
async def upload_photo(user_id: int, image: UploadFile = File(...), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.avatar_data = await image.read()
    db.commit()
    return {"uploaded": True}

@router.get("/{user_id}/photo")
def get_photo(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.avatar_data:
        raise HTTPException(status_code=404, detail="No photo set")
    return Response(content=user.avatar_data, media_type="image/jpeg")
