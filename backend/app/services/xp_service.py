from sqlalchemy.orm import Session
from app.models import User, XPEvent


def _title_for_level(level: int) -> str:
    if level >= 30:
        return "Legend"
    if level >= 20:
        return "Champion"
    if level >= 15:
        return "Athlete"
    if level >= 10:
        return "Runner"
    if level >= 5:
        return "Walker"
    return "Novice"


def _xp_required_for_level(level: int) -> int:
    """Cumulative XP needed to reach `level`. Triangular number * 100."""
    return (level - 1) * level // 2 * 100


def _level_for_xp(total_xp: int) -> int:
    level = 1
    while _xp_required_for_level(level + 1) <= total_xp:
        level += 1
    return level


def award_xp(db: Session, user_id: int, amount: int, reason: str) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    event = XPEvent(user_id=user_id, xp_gained=amount, reason=reason)
    db.add(event)

    old_level = user.level
    user.xp += amount
    new_level = _level_for_xp(user.xp)

    leveled_up = new_level > old_level
    if leveled_up:
        user.level = new_level
        user.title = _title_for_level(new_level)

    db.commit()
    db.refresh(user)

    result = {"user": user, "leveled_up": leveled_up}
    if leveled_up:
        result["new_level"] = new_level
        result["new_title"] = user.title
    return result


def revoke_xp(db: Session, user_id: int, amount: int, reason: str) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    event = XPEvent(user_id=user_id, xp_gained=-amount, reason=reason)
    db.add(event)

    old_level = user.level
    user.xp = max(0, user.xp - amount)
    new_level = _level_for_xp(user.xp)

    leveled_down = new_level < old_level
    if leveled_down:
        user.level = new_level
        user.title = _title_for_level(new_level)

    db.commit()
    db.refresh(user)

    result = {"user": user, "leveled_down": leveled_down}
    if leveled_down:
        result["new_level"] = new_level
        result["new_title"] = user.title
    return result
