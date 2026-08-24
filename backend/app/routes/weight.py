from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, WeightLog
from app.services.xp_service import award_xp
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/weight", tags=["weight"])


class WeightLogRequest(BaseModel):
    user_id: int
    weight: float


@router.post("/log")
def log_weight(payload: WeightLogRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == payload.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    log = WeightLog(user_id=payload.user_id, weight=payload.weight)
    db.add(log)
    user.current_weight = payload.weight
    db.commit()
    db.refresh(log)

    xp_result = award_xp(db, payload.user_id, 30, "weekly_weigh_in")
    user = xp_result["user"]

    return {
        "user": {
            "id": user.id,
            "name": user.name,
            "xp": user.xp,
            "level": user.level,
            "title": user.title,
            "current_weight": user.current_weight,
        },
        "weight_log": {
            "id": log.id,
            "weight": log.weight,
            "logged_at": log.logged_at,
        },
        "leveled_up": xp_result["leveled_up"],
        "new_level": xp_result.get("new_level"),
        "new_title": xp_result.get("new_title"),
    }


@router.get("/history/{user_id}")
def weight_history(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    logs = (
        db.query(WeightLog)
        .filter(WeightLog.user_id == user_id)
        .order_by(WeightLog.logged_at.desc())
        .all()
    )

    first_weight = logs[-1].weight if logs else user.current_weight
    total_change = round(user.current_weight - first_weight, 2)

    return {
        "user_id": user_id,
        "total_change": total_change,
        "logs": [
            {"id": l.id, "weight": l.weight, "logged_at": l.logged_at}
            for l in logs
        ],
    }
