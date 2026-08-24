from app.database import Base
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, LargeBinary
from sqlalchemy.orm import relationship
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    age = Column(Integer)
    height_cm = Column(Float)
    current_weight = Column(Float)
    goal_weight = Column(Float)
    xp = Column(Integer, default=0)
    level = Column(Integer, default=1)
    title = Column(String, default="Novice")
    avatar_data = Column(LargeBinary, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    weight_logs = relationship("WeightLog", back_populates="user")
    food_logs = relationship("FoodLog", back_populates="user")
    user_quests = relationship("UserQuest", back_populates="user")
    xp_events = relationship("XPEvent", back_populates="user")
    coach_messages = relationship("CoachMessage", back_populates="user")

class WeightLog(Base):
    __tablename__ = "weight_logs"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    weight = Column(Float)
    logged_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="weight_logs")

class Quest(Base):
    __tablename__ = "quests"
    id = Column(Integer, primary_key=True)
    title = Column(String)
    description = Column(String)
    quest_type = Column(String)
    diet_metric = Column(String, nullable=True)  # "calories" or "protein", only for quest_type == "diet"
    target_value = Column(Float)
    xp_reward = Column(Integer)
    rarity = Column(String, default="common")

class UserQuest(Base):
    __tablename__ = "user_quests"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    quest_id = Column(Integer, ForeignKey("quests.id"))
    assigned_date = Column(DateTime, default=datetime.utcnow)
    completed = Column(Boolean, default=False)
    completed_at = Column(DateTime, nullable=True)
    auto_completed = Column(Boolean, default=False)
    progress_value = Column(Float, default=0)
    user = relationship("User", back_populates="user_quests")
    quest = relationship("Quest")

class FoodLog(Base):
    __tablename__ = "food_logs"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    status = Column(String, default="pending")
    food_name = Column(String)
    estimated_calories = Column(Float)
    estimated_protein = Column(Float)
    estimated_fat = Column(Float)
    estimated_carbs = Column(Float)
    confidence_score = Column(Float)
    logged_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="food_logs")
    images = relationship("FoodLogImage", back_populates="food_log", order_by="FoodLogImage.created_at")


class FoodLogImage(Base):
    __tablename__ = "food_log_images"
    id = Column(Integer, primary_key=True)
    food_log_id = Column(Integer, ForeignKey("food_logs.id"))
    image_data = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    food_log = relationship("FoodLog", back_populates="images")

class XPEvent(Base):
    __tablename__ = "xp_events"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    xp_gained = Column(Integer)
    reason = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="xp_events")

class CoachMessage(Base):
    __tablename__ = "coach_messages"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    role = Column(String, nullable=False)  # "user" or "assistant"
    content = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="coach_messages")
