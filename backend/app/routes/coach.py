from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.models import CoachMessage
from app.services.coach_service import chat_with_coach

router = APIRouter(prefix="/coach", tags=["coach"])


class ChatRequest(BaseModel):
    user_id: int
    message: str


def _format_message(m: CoachMessage) -> dict:
    return {"id": m.id, "role": m.role, "content": m.content, "created_at": m.created_at}


@router.post("/chat")
def chat(body: ChatRequest, db: Session = Depends(get_db)):
    try:
        reply = chat_with_coach(db, body.user_id, body.message)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Coach is temporarily unavailable: {e}")
    return {"reply": reply}


@router.get("/history/{user_id}")
def history(user_id: int, db: Session = Depends(get_db)):
    messages = (
        db.query(CoachMessage)
        .filter(CoachMessage.user_id == user_id)
        .order_by(CoachMessage.created_at.asc())
        .all()
    )
    return {"user_id": user_id, "messages": [_format_message(m) for m in messages]}
