import random
from datetime import date, datetime
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.models import Quest, UserQuest, User, FoodLog
from app.services.xp_service import award_xp, revoke_xp
from app.services.gemini_client import get_client, extract_json
from app.services.user_context import gather_user_context, format_context_text

QUEST_CATEGORIES = ["walking", "running", "swimming", "diet", "hiking"]

RARITY_XP = {"common": 40, "rare": 70, "epic": 110, "legendary": 160}

# (low, high) sane bounds per category/metric — used to clamp whatever the model returns
TARGET_RANGES = {
    "walking": (1, 10),        # km
    "running": (1, 15),        # km
    "swimming": (100, 3000),   # meters
    "hiking": (2, 20),         # km
    "diet_calories": (1200, 3500),
    "diet_protein": (50, 220),
}

QUEST_SPEC_PROMPT = """You are generating daily fitness quests for a gamified fitness app.

User's current data:
{context}

Only choose from these categories: walking, running, swimming, diet, hiking.
For "diet" quests, also pick a diet_metric of either "calories" (stay under X kcal) or "protein" (hit at least Xg protein).
Pick targets that are attainable but a bit challenging given this specific user's level and recent activity — do not just use round default numbers, actually reason about what's realistic for them.
Generate exactly {n} quest(s), using distinct categories from each other.{exclusion_note}

Return ONLY valid JSON in exactly this shape, no markdown, no other text:
{{"quests": [{{"category": "walking", "diet_metric": null, "target": number, "rarity": "common"}}]}}
rarity must be one of: common, rare, epic, legendary (harder/longer targets should be rarer).
target must be a positive number: walking/running/hiking in kilometers, swimming in meters, diet in kcal (calories metric) or grams (protein metric).
"""


def _level_target(user: User, category: str, diet_metric: str | None = None) -> float:
    level = user.level or 1
    if category == "walking":
        return round(2 + level * 0.3, 1)
    if category == "running":
        return round(1.5 + level * 0.35, 1)
    if category == "swimming":
        return round(300 + level * 40)
    if category == "hiking":
        return round(3 + level * 0.5, 1)
    if category == "diet":
        if diet_metric == "protein":
            return round(100 + level * 3)
        return 1800
    raise ValueError(category)


def _fallback_spec(user: User, category: str) -> dict:
    diet_metric = random.choice(["calories", "protein"]) if category == "diet" else None
    target = _level_target(user, category, diet_metric)
    return {"category": category, "diet_metric": diet_metric, "target": target, "rarity": "common"}


def _fallback_specs(user: User, n: int, exclude_categories: list[str] | None = None) -> list[dict]:
    cats = [c for c in QUEST_CATEGORIES if not exclude_categories or c not in exclude_categories]
    if not cats:
        cats = QUEST_CATEGORIES
    picks = random.sample(cats, min(n, len(cats)))
    return [_fallback_spec(user, c) for c in picks]


def _clamp_spec(spec: dict) -> dict | None:
    category = spec.get("category")
    if category not in QUEST_CATEGORIES:
        return None
    try:
        target = float(spec.get("target"))
    except (TypeError, ValueError):
        return None

    diet_metric = None
    if category == "diet":
        diet_metric = spec.get("diet_metric")
        if diet_metric not in ("calories", "protein"):
            diet_metric = "calories"
        lo, hi = TARGET_RANGES[f"diet_{diet_metric}"]
    else:
        lo, hi = TARGET_RANGES[category]
    target = max(lo, min(hi, target))

    rarity = spec.get("rarity")
    if rarity not in RARITY_XP:
        rarity = "common"

    return {"category": category, "diet_metric": diet_metric, "target": round(target, 1), "rarity": rarity}


def _generate_specs_via_ai(
    context_text: str, n: int, exclude_categories: list[str] | None, preferred_category: str | None
) -> list[dict]:
    exclusion_note = ""
    if preferred_category:
        exclusion_note = f" The user specifically wants a quest in the '{preferred_category}' category — use exactly that category."
    elif exclude_categories:
        exclusion_note = f" Avoid these categories, the user already has them today: {', '.join(exclude_categories)}."

    prompt = QUEST_SPEC_PROMPT.format(context=context_text, n=n, exclusion_note=exclusion_note)
    client = get_client()
    response = client.models.generate_content(model="gemini-2.5-flash", contents=[prompt])
    data = extract_json(response.text)
    return data.get("quests", [])[:n]


def _quest_fields_from_spec(spec: dict) -> dict:
    category = spec["category"]
    target = spec["target"]
    rarity = spec["rarity"]

    if category == "walking":
        title, description = f"Walk {target:g}km", f"Walk at least {target:g} kilometers today"
    elif category == "running":
        title, description = f"Run {target:g}km", f"Run at least {target:g} kilometers today"
    elif category == "swimming":
        title, description = f"Swim {target:g}m", f"Swim at least {target:g} meters today"
    elif category == "hiking":
        title, description = f"Hike {target:g}km", f"Complete a hike of at least {target:g} kilometers"
    elif category == "diet" and spec.get("diet_metric") == "protein":
        title, description = f"Hit {target:g}g protein", f"Eat at least {target:g}g of protein today"
    else:
        title, description = f"Stay under {target:g} kcal", f"Stay under {target:g} calories today"

    return {
        "title": title,
        "description": description,
        "quest_type": category,
        "diet_metric": spec.get("diet_metric") if category == "diet" else None,
        "target_value": target,
        "xp_reward": RARITY_XP[rarity],
        "rarity": rarity,
    }


def _build_quest_specs(
    user: User, context_text: str, n: int, exclude_categories: list[str] | None = None, preferred_category: str | None = None
) -> list[dict]:
    try:
        raw_specs = _generate_specs_via_ai(context_text, n, exclude_categories, preferred_category)
        valid = [s for s in (_clamp_spec(s) for s in raw_specs) if s]
        if preferred_category:
            valid = [s for s in valid if s["category"] == preferred_category]
    except Exception:
        valid = []

    if len(valid) < n:
        needed = n - len(valid)
        have_categories = [s["category"] for s in valid] + (exclude_categories or [])
        if preferred_category:
            fallback = [_fallback_spec(user, preferred_category) for _ in range(needed)]
        else:
            fallback = _fallback_specs(user, needed, exclude_categories=have_categories)
        valid.extend(fallback)

    return valid[:n]


def resolve_past_calorie_quests(db: Session, user_id: int) -> None:
    """EOD reconciliation: a 'stay under X kcal' quest can only be judged once its day has passed."""
    today = date.today()
    pending = (
        db.query(UserQuest)
        .join(Quest)
        .filter(
            UserQuest.user_id == user_id,
            UserQuest.completed == False,  # noqa: E712
            func.date(UserQuest.assigned_date) < today,
            Quest.quest_type == "diet",
            Quest.diet_metric == "calories",
        )
        .all()
    )
    for uq in pending:
        quest_date = uq.assigned_date.date()
        total_calories = (
            db.query(func.coalesce(func.sum(FoodLog.estimated_calories), 0.0))
            .filter(
                FoodLog.user_id == user_id,
                FoodLog.status == "confirmed",
                func.date(FoodLog.logged_at) == quest_date,
            )
            .scalar()
        )
        if total_calories <= uq.quest.target_value:
            uq.completed = True
            uq.completed_at = datetime.combine(quest_date, datetime.min.time())
            uq.auto_completed = True
            db.commit()
            db.refresh(uq)
            award_xp(db, user_id, uq.quest.xp_reward, "quest_auto_completed_eod")


def sync_diet_quests_for_date(db: Session, user_id: int, target_date: date) -> None:
    """Real-time reconciliation for 'hit Xg protein' quests, triggered whenever a food log changes."""
    quests_today = (
        db.query(UserQuest)
        .join(Quest)
        .filter(
            UserQuest.user_id == user_id,
            func.date(UserQuest.assigned_date) == target_date,
            Quest.quest_type == "diet",
            Quest.diet_metric == "protein",
        )
        .all()
    )
    if not quests_today:
        return

    total_protein = (
        db.query(func.coalesce(func.sum(FoodLog.estimated_protein), 0.0))
        .filter(
            FoodLog.user_id == user_id,
            FoodLog.status == "confirmed",
            func.date(FoodLog.logged_at) == target_date,
        )
        .scalar()
    )

    for uq in quests_today:
        target = uq.quest.target_value
        if total_protein >= target and not uq.completed:
            uq.completed = True
            uq.completed_at = datetime.utcnow()
            uq.auto_completed = True
            db.commit()
            db.refresh(uq)
            award_xp(db, user_id, uq.quest.xp_reward, "quest_auto_completed")
        elif total_protein < target and uq.completed and uq.auto_completed:
            uq.completed = False
            uq.completed_at = None
            uq.auto_completed = False
            db.commit()
            db.refresh(uq)
            revoke_xp(db, user_id, uq.quest.xp_reward, "quest_auto_undone")


def assign_daily_quests(db: Session, user_id: int) -> list[UserQuest]:
    resolve_past_calorie_quests(db, user_id)

    today = date.today()

    existing = (
        db.query(UserQuest)
        .filter(
            UserQuest.user_id == user_id,
            func.date(UserQuest.assigned_date) == today,
        )
        .all()
    )
    if existing:
        return existing

    context = gather_user_context(db, user_id)
    if not context:
        return []

    specs = _build_quest_specs(context["user"], format_context_text(context), n=3)

    assigned_dt = datetime.combine(today, datetime.min.time())
    new_quests = []
    for spec in specs:
        quest = Quest(**_quest_fields_from_spec(spec))
        db.add(quest)
        db.flush()
        uq = UserQuest(user_id=user_id, quest_id=quest.id, assigned_date=assigned_dt)
        db.add(uq)
        new_quests.append(uq)

    db.commit()
    for uq in new_quests:
        db.refresh(uq)

    return new_quests


def replace_quest(db: Session, user_id: int, user_quest_id: int, preferred_category: str | None = None) -> UserQuest | None:
    uq = (
        db.query(UserQuest)
        .filter(UserQuest.id == user_quest_id, UserQuest.user_id == user_id)
        .first()
    )
    if not uq:
        return None
    if uq.completed:
        raise ValueError("Cannot replace a completed quest")
    if preferred_category and preferred_category not in QUEST_CATEGORIES:
        raise ValueError("Invalid category")

    today = date.today()
    sibling_categories = [
        sibling.quest.quest_type
        for sibling in db.query(UserQuest)
        .filter(
            UserQuest.user_id == user_id,
            func.date(UserQuest.assigned_date) == today,
            UserQuest.id != user_quest_id,
        )
        .all()
    ]

    context = gather_user_context(db, user_id)
    spec = _build_quest_specs(
        context["user"],
        format_context_text(context),
        n=1,
        exclude_categories=sibling_categories + [uq.quest.quest_type],
        preferred_category=preferred_category,
    )[0]

    old_quest_id = uq.quest_id
    new_quest = Quest(**_quest_fields_from_spec(spec))
    db.add(new_quest)
    db.flush()

    uq.quest_id = new_quest.id
    uq.assigned_date = datetime.combine(today, datetime.min.time())
    db.commit()
    db.refresh(uq)

    still_used = db.query(UserQuest).filter(UserQuest.quest_id == old_quest_id).count()
    if still_used == 0:
        db.query(Quest).filter(Quest.id == old_quest_id).delete()
        db.commit()

    return uq


def complete_quest(db: Session, user_id: int, user_quest_id: int) -> dict:
    uq = (
        db.query(UserQuest)
        .filter(UserQuest.id == user_quest_id, UserQuest.user_id == user_id)
        .first()
    )
    if not uq:
        return None

    if uq.completed:
        return {"already_completed": True, "user_quest": uq}

    uq.completed = True
    uq.completed_at = datetime.utcnow()
    db.commit()
    db.refresh(uq)

    xp_result = award_xp(db, user_id, uq.quest.xp_reward, "quest_completed")

    return {
        "already_completed": False,
        "user_quest": uq,
        "xp_result": xp_result,
    }


def uncomplete_quest(db: Session, user_id: int, user_quest_id: int) -> dict:
    uq = (
        db.query(UserQuest)
        .filter(UserQuest.id == user_quest_id, UserQuest.user_id == user_id)
        .first()
    )
    if not uq:
        return None

    if not uq.completed:
        return {"already_incomplete": True, "user_quest": uq}

    uq.completed = False
    uq.completed_at = None
    uq.auto_completed = False
    db.commit()
    db.refresh(uq)

    xp_result = revoke_xp(db, user_id, uq.quest.xp_reward, "quest_undone")

    return {
        "already_incomplete": False,
        "user_quest": uq,
        "xp_result": xp_result,
    }
