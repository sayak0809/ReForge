from sqlalchemy.orm import Session
from app.models import User, WeightLog, FoodLog, UserQuest, CoachMessage

COACH_HISTORY_LIMIT = 10


def gather_user_context(db: Session, user_id: int) -> dict | None:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    weight_logs = (
        db.query(WeightLog)
        .filter(WeightLog.user_id == user_id)
        .order_by(WeightLog.logged_at.desc())
        .limit(5)
        .all()
    )
    food_logs = (
        db.query(FoodLog)
        .filter(FoodLog.user_id == user_id, FoodLog.status == "confirmed")
        .order_by(FoodLog.logged_at.desc())
        .limit(5)
        .all()
    )
    recent_quests = (
        db.query(UserQuest)
        .filter(UserQuest.user_id == user_id)
        .order_by(UserQuest.assigned_date.desc())
        .limit(10)
        .all()
    )
    coach_messages = (
        db.query(CoachMessage)
        .filter(CoachMessage.user_id == user_id)
        .order_by(CoachMessage.created_at.desc())
        .limit(COACH_HISTORY_LIMIT)
        .all()
    )
    coach_messages = list(reversed(coach_messages))

    return {
        "user": user,
        "weight_logs": weight_logs,
        "food_logs": food_logs,
        "recent_quests": recent_quests,
        "coach_messages": coach_messages,
    }


def format_context_text(ctx: dict) -> str:
    user = ctx["user"]
    lines = [
        f"Name: {user.name}",
        f"Age: {user.age}",
        f"Height: {user.height_cm} cm",
        f"Current weight: {user.current_weight} kg",
        f"Goal weight: {user.goal_weight} kg",
        f"Level: {user.level} ({user.title}), XP: {user.xp}",
    ]

    if ctx["weight_logs"]:
        lines.append(
            "Recent weight log (most recent first): "
            + ", ".join(f"{w.weight}kg on {w.logged_at.date()}" for w in ctx["weight_logs"])
        )
    else:
        lines.append("No weight log entries yet.")

    if ctx["food_logs"]:
        lines.append(
            "Recent confirmed meals: "
            + "; ".join(
                f"{fl.food_name or 'meal'} "
                f"({(fl.estimated_calories or 0):.0f} kcal, {(fl.estimated_protein or 0):.0f}g protein, "
                f"{(fl.estimated_fat or 0):.0f}g fat, {(fl.estimated_carbs or 0):.0f}g carbs)"
                for fl in ctx["food_logs"]
            )
        )
    else:
        lines.append("No confirmed meals logged yet.")

    if ctx["recent_quests"]:
        lines.append(
            "Recent quests: "
            + "; ".join(
                f"{uq.quest.title} [{uq.quest.quest_type}] - {'done' if uq.completed else 'not done'}"
                for uq in ctx["recent_quests"]
            )
        )
    else:
        lines.append("No quests assigned yet.")

    if ctx.get("coach_messages"):
        lines.append(
            "Recent conversation with Coach (may contain preferences to respect, e.g. injuries or dislikes): "
            + " | ".join(f"{m.role}: {m.content}" for m in ctx["coach_messages"])
        )

    return "\n".join(lines)
