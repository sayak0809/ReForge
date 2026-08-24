from app.database import engine, Base
from app.models import User, WeightLog, Quest, UserQuest, FoodLog, FoodLogImage, XPEvent, CoachMessage

Base.metadata.create_all(bind=engine)
print("All tables created! ✅")
