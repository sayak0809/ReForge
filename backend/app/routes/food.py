from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, FoodLog, FoodLogImage
from app.services.ai_service import analyze_food_images
from app.services.xp_service import award_xp
from app.services.quest_service import sync_diet_quests_for_date

router = APIRouter(prefix="/food", tags=["food"])


def _format_food_log(fl: FoodLog) -> dict:
    return {
        "id": fl.id,
        "status": fl.status,
        "items": fl.food_name.split(", ") if fl.food_name else [],
        "estimated_calories": fl.estimated_calories,
        "estimated_protein": fl.estimated_protein,
        "estimated_fat": fl.estimated_fat,
        "estimated_carbs": fl.estimated_carbs,
        "confidence_score": fl.confidence_score,
        "photo_count": len(fl.images),
        "image_ids": [img.id for img in fl.images],
        "logged_at": fl.logged_at,
    }


async def _run_analysis_and_update(db: Session, food_log: FoodLog) -> dict:
    all_image_bytes = [img.image_data for img in food_log.images]
    return await analyze_food_images(all_image_bytes)


@router.post("/log")
async def log_food(
    user_id: int = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    image_bytes = await image.read()

    food_log = FoodLog(user_id=user_id, status="pending")
    db.add(food_log)
    db.flush()  # get food_log.id before adding image

    db.add(FoodLogImage(food_log_id=food_log.id, image_data=image_bytes))
    db.commit()
    db.refresh(food_log)

    try:
        result = await analyze_food_images([image_bytes])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI analysis failed: {e}")

    confidence = result.get("confidence", 0)
    food_log.food_name = ", ".join(result.get("items", [])) or None
    food_log.estimated_calories = result.get("calories")
    food_log.estimated_protein = result.get("protein_g")
    food_log.estimated_fat = result.get("fat_g")
    food_log.estimated_carbs = result.get("carbs_g")
    food_log.confidence_score = confidence

    response = {"food_log": _format_food_log(food_log), "items": result.get("items", [])}

    if confidence >= 0.8:
        old_level = user.level
        food_log.status = "confirmed"
        db.commit()
        db.refresh(food_log)
        award_xp(db, user_id, 20, "meal_logged")
        sync_diet_quests_for_date(db, user_id, food_log.logged_at.date())
        db.refresh(user)
        leveled_up = user.level > old_level
        response["food_log"] = _format_food_log(food_log)
        response["xp_awarded"] = 20
        response["user"] = {"id": user.id, "name": user.name, "xp": user.xp, "level": user.level, "title": user.title}
        response["leveled_up"] = leveled_up
        response["new_level"] = user.level if leveled_up else None
        response["new_title"] = user.title if leveled_up else None
    else:
        db.commit()
        db.refresh(food_log)
        response["food_log"] = _format_food_log(food_log)
        response["needs_better_photo"] = True
        response["message"] = "Confidence too low — add another photo from a different angle."

    return response


@router.post("/log/manual")
async def log_food_manual(
    user_id: int = Form(...),
    name: str = Form(...),
    calories: float = Form(...),
    protein_g: float | None = Form(None),
    fat_g: float | None = Form(None),
    carbs_g: float | None = Form(None),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    food_log = FoodLog(
        user_id=user_id,
        status="confirmed",
        food_name=name,
        estimated_calories=calories,
        estimated_protein=protein_g,
        estimated_fat=fat_g,
        estimated_carbs=carbs_g,
        confidence_score=1.0,
    )
    db.add(food_log)
    db.flush()  # get food_log.id before adding image

    if image is not None:
        image_bytes = await image.read()
        db.add(FoodLogImage(food_log_id=food_log.id, image_data=image_bytes))

    db.commit()
    db.refresh(food_log)

    old_level = user.level
    award_xp(db, user_id, 20, "meal_logged")
    sync_diet_quests_for_date(db, user_id, food_log.logged_at.date())
    db.refresh(user)
    leveled_up = user.level > old_level

    return {
        "food_log": _format_food_log(food_log),
        "xp_awarded": 20,
        "user": {"id": user.id, "name": user.name, "xp": user.xp, "level": user.level, "title": user.title},
        "leveled_up": leveled_up,
        "new_level": user.level if leveled_up else None,
        "new_title": user.title if leveled_up else None,
    }


@router.post("/log/{food_log_id}/add-photo")
async def add_photo(
    food_log_id: int,
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    food_log = db.query(FoodLog).filter(FoodLog.id == food_log_id).first()
    if not food_log:
        raise HTTPException(status_code=404, detail="Food log not found")
    if food_log.status == "confirmed":
        raise HTTPException(status_code=400, detail="Food log already confirmed — no more photos needed.")

    image_bytes = await image.read()
    db.add(FoodLogImage(food_log_id=food_log_id, image_data=image_bytes))
    db.commit()
    db.refresh(food_log)

    try:
        result = await _run_analysis_and_update(db, food_log)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI analysis failed: {e}")

    confidence = result.get("confidence", 0)
    food_log.food_name = ", ".join(result.get("items", [])) or None
    food_log.estimated_calories = result.get("calories")
    food_log.estimated_protein = result.get("protein_g")
    food_log.estimated_fat = result.get("fat_g")
    food_log.estimated_carbs = result.get("carbs_g")
    food_log.confidence_score = confidence

    response = {"food_log": _format_food_log(food_log), "items": result.get("items", [])}

    if confidence >= 0.8:
        user = db.query(User).filter(User.id == food_log.user_id).first()
        old_level = user.level
        food_log.status = "confirmed"
        db.commit()
        db.refresh(food_log)
        award_xp(db, food_log.user_id, 20, "meal_logged")
        sync_diet_quests_for_date(db, food_log.user_id, food_log.logged_at.date())
        db.refresh(user)
        leveled_up = user.level > old_level
        response["food_log"] = _format_food_log(food_log)
        response["xp_awarded"] = 20
        response["user"] = {"id": user.id, "name": user.name, "xp": user.xp, "level": user.level, "title": user.title}
        response["leveled_up"] = leveled_up
        response["new_level"] = user.level if leveled_up else None
        response["new_title"] = user.title if leveled_up else None
    else:
        db.commit()
        db.refresh(food_log)
        response["food_log"] = _format_food_log(food_log)
        response["needs_better_photo"] = True
        response["message"] = f"Still low confidence after {len(food_log.images)} photo(s) — try another angle."

    return response


@router.delete("/log/{food_log_id}")
def delete_food_log(food_log_id: int, db: Session = Depends(get_db)):
    food_log = db.query(FoodLog).filter(FoodLog.id == food_log_id).first()
    if not food_log:
        raise HTTPException(status_code=404, detail="Food log not found")

    user_id = food_log.user_id
    log_date = food_log.logged_at.date()
    was_confirmed = food_log.status == "confirmed"

    db.query(FoodLogImage).filter(FoodLogImage.food_log_id == food_log_id).delete()
    db.delete(food_log)
    db.commit()

    if was_confirmed:
        sync_diet_quests_for_date(db, user_id, log_date)

    return {"deleted": True, "id": food_log_id}


@router.get("/images/{image_id}")
def get_food_image(image_id: int, db: Session = Depends(get_db)):
    image = db.query(FoodLogImage).filter(FoodLogImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    return Response(content=image.image_data, media_type="image/jpeg")


@router.get("/history/{user_id}")
def food_history(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    logs = (
        db.query(FoodLog)
        .filter(FoodLog.user_id == user_id)
        .order_by(FoodLog.logged_at.desc())
        .all()
    )

    return {
        "user_id": user_id,
        "logs": [_format_food_log(fl) for fl in logs],
    }
