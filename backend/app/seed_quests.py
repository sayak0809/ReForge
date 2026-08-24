from app.database import SessionLocal
from app.models import Quest

QUESTS = [
    {"title": "Walk 6000 steps",    "description": "Take 6000 steps today",          "quest_type": "steps",    "target_value": 6000, "xp_reward": 50,  "rarity": "common"},
    {"title": "Walk 8000 steps",    "description": "Take 8000 steps today",          "quest_type": "steps",    "target_value": 8000, "xp_reward": 80,  "rarity": "rare"},
    {"title": "Run 3km",            "description": "Run 3 kilometers",               "quest_type": "workout",  "target_value": 3,    "xp_reward": 70,  "rarity": "common"},
    {"title": "Run 5km",            "description": "Run 5 kilometers",               "quest_type": "workout",  "target_value": 5,    "xp_reward": 120, "rarity": "rare"},
    {"title": "Hit 130g protein",   "description": "Eat at least 130g of protein",   "quest_type": "protein",  "target_value": 130,  "xp_reward": 60,  "rarity": "common"},
    {"title": "Stay under 1850 kcal","description": "Stay under 1850 calories today","quest_type": "calories", "target_value": 1850, "xp_reward": 60,  "rarity": "common"},
    {"title": "Complete a hike",    "description": "Complete one hike",              "quest_type": "workout",  "target_value": 1,    "xp_reward": 100, "rarity": "epic"},
]

def seed():
    db = SessionLocal()
    existing_titles = {q.title for q in db.query(Quest.title).all()}
    added = 0
    for data in QUESTS:
        if data["title"] not in existing_titles:
            db.add(Quest(**data))
            added += 1
    db.commit()
    db.close()
    print(f"Seeded {added} quest(s). {len(QUESTS) - added} already existed.")

if __name__ == "__main__":
    seed()
