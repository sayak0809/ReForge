from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.models import UserQuest
from app.services.quest_service import (
    assign_daily_quests,
    complete_quest,
    uncomplete_quest,
    replace_quest,
    QUEST_CATEGORIES,
)

router = APIRouter(prefix="/quests", tags=["quests"])


class ReplaceQuestRequest(BaseModel):
    preferred_category: str | None = None


def _format_user_quest(uq: UserQuest) -> dict:
    return {
        "user_quest_id": uq.id,
        "quest_id": uq.quest.id,
        "title": uq.quest.title,
        "description": uq.quest.description,
        "quest_type": uq.quest.quest_type,
        "target_value": uq.quest.target_value,
        "xp_reward": uq.quest.xp_reward,
        "rarity": uq.quest.rarity,
        "completed": uq.completed,
        "auto_completed": uq.auto_completed,
        "completed_at": uq.completed_at,
        "assigned_date": uq.assigned_date,
    }


@router.post("/assign/{user_id}")
def assign_quests(user_id: int, db: Session = Depends(get_db)):
    assigned = assign_daily_quests(db, user_id)
    if not assigned:
        return {"message": "No new quests to assign today", "quests": []}
    return {
        "message": f"Assigned {len(assigned)} quest(s)",
        "quests": [_format_user_quest(uq) for uq in assigned],
    }


@router.get("/today/{user_id}")
def today_quests(user_id: int, db: Session = Depends(get_db)):
    quests = assign_daily_quests(db, user_id)
    return {
        "user_id": user_id,
        "quests": [_format_user_quest(uq) for uq in quests],
    }


@router.get("/categories")
def categories():
    return {"categories": QUEST_CATEGORIES}


@router.post("/{user_quest_id}/replace")
def replace(user_quest_id: int, body: ReplaceQuestRequest = ReplaceQuestRequest(), db: Session = Depends(get_db)):
    uq_row = db.query(UserQuest).filter(UserQuest.id == user_quest_id).first()
    if not uq_row:
        raise HTTPException(status_code=404, detail="UserQuest not found")

    try:
        updated = replace_quest(db, uq_row.user_id, user_quest_id, body.preferred_category)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {"quest": _format_user_quest(updated)}


@router.post("/complete/{user_quest_id}")
def complete(user_quest_id: int, db: Session = Depends(get_db)):
    uq_row = db.query(UserQuest).filter(UserQuest.id == user_quest_id).first()
    if not uq_row:
        raise HTTPException(status_code=404, detail="UserQuest not found")

    result = complete_quest(db, uq_row.user_id, user_quest_id)

    if result.get("already_completed"):
        return {"message": "Quest already completed", "user_quest": _format_user_quest(result["user_quest"])}

    xp = result["xp_result"]
    user = xp["user"]
    return {
        "message": "Quest completed!",
        "user_quest": _format_user_quest(result["user_quest"]),
        "xp_awarded": result["user_quest"].quest.xp_reward,
        "user": {
            "id": user.id,
            "name": user.name,
            "xp": user.xp,
            "level": user.level,
            "title": user.title,
        },
        "leveled_up": xp["leveled_up"],
        "new_level": xp.get("new_level"),
        "new_title": xp.get("new_title"),
    }


@router.post("/uncomplete/{user_quest_id}")
def uncomplete(user_quest_id: int, db: Session = Depends(get_db)):
    uq_row = db.query(UserQuest).filter(UserQuest.id == user_quest_id).first()
    if not uq_row:
        raise HTTPException(status_code=404, detail="UserQuest not found")

    result = uncomplete_quest(db, uq_row.user_id, user_quest_id)

    if result.get("already_incomplete"):
        return {"message": "Quest already incomplete", "user_quest": _format_user_quest(result["user_quest"])}

    xp = result["xp_result"]
    user = xp["user"]
    return {
        "message": "Quest undone",
        "user_quest": _format_user_quest(result["user_quest"]),
        "xp_revoked": result["user_quest"].quest.xp_reward,
        "user": {
            "id": user.id,
            "name": user.name,
            "xp": user.xp,
            "level": user.level,
            "title": user.title,
        },
        "leveled_down": xp["leveled_down"],
        "new_level": xp.get("new_level"),
        "new_title": xp.get("new_title"),
    }
