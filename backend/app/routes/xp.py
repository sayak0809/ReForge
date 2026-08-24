from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.xp_service import award_xp
from pydantic import BaseModel

router = APIRouter(prefix="/xp", tags=["xp"])


class AwardXPRequest(BaseModel):
    user_id: int
    amount: int
    reason: str


@router.post("/award")
def award_xp_endpoint(payload: AwardXPRequest, db: Session = Depends(get_db)):
    result = award_xp(db, payload.user_id, payload.amount, payload.reason)
    if result is None:
        raise HTTPException(status_code=404, detail="User not found")

    user = result["user"]
    return {
        "user_id": user.id,
        "name": user.name,
        "xp": user.xp,
        "level": user.level,
        "title": user.title,
        "leveled_up": result["leveled_up"],
        "new_level": result.get("new_level"),
        "new_title": result.get("new_title"),
    }
