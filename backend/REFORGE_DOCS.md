# Reforge — Project Documentation

> A living document updated at the end of every build session.
> Written for someone who wants to understand what was built, why, and how.

---

## What is Reforge?

Reforge is an AI-powered fitness RPG app for iOS. The core idea is simple: your real life becomes a game. You log food, complete workouts, hit daily targets — and your character levels up. The app assigns you quests every day, tracks your XP, and adapts to your behaviour over time.

The first user is the founder himself — a 25-year-old data scientist currently cutting from 75kg to 62kg. Every feature is built around a real person with real goals.

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Mobile app | Flutter (iOS) | One codebase, native performance |
| Backend API | FastAPI (Python) | Fast to build, founder knows Python |
| Database | PostgreSQL | Reliable, relational, great for RPG data |
| AI (food + coach) | Google Gemini (free tier) | Free to start, has vision for food photos |
| Local DB | Docker | Runs PostgreSQL locally without installing anything |
| Deployment | Railway (planned) | Simple, affordable, one-click Postgres |

---

## Session 1 — June 15, 2026

### What we built
The entire foundation of the backend: environment setup, database, models, and the first working API endpoint.

### Environment Setup

**Tools installed on Mac (Apple Silicon):**
- Homebrew — Mac package manager, installed via Terminal
- Python 3.12 — installed via official python.org installer (Homebrew Python had compatibility issues with macOS 26 beta)
- Flutter 3.44.2 — downloaded manually due to connection issues with Homebrew CDN
- Xcode 26.5 + iOS 26.5 Simulator — installed via App Store and Xcode settings
- CocoaPods — installed via Homebrew (`brew install cocoapods`)
- Docker Desktop — for running PostgreSQL locally
- VS Code — code editor with Flutter and Python extensions
- uv — modern Python package manager (installed but not used due to macOS 26 issues)

**Python virtual environment:**
```bash
/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn sqlalchemy psycopg2-binary alembic pydantic python-dotenv
```

> Note: Homebrew Python 3.11 and 3.12 both had broken `ensurepip` on macOS 26 beta. The official Python.org installer worked correctly.

---

### Project Structure

```
reforge-backend/
├── app/
│   ├── __init__.py
│   ├── main.py          ← FastAPI app, routes registered here
│   ├── database.py      ← DB connection, session, Base
│   ├── models/
│   │   └── __init__.py  ← All SQLAlchemy table definitions
│   ├── routes/
│   │   └── users.py     ← User creation and retrieval endpoints
│   └── services/        ← Business logic (quest engine, XP — coming soon)
├── create_tables.py     ← One-time script to create DB tables
├── docker-compose.yml   ← Runs PostgreSQL in a container
├── .env                 ← Environment variables (never commit this)
└── requirements.txt     ← Python dependencies
```

---

### Database

PostgreSQL runs locally inside Docker. Started with:
```bash
docker-compose up -d
```

**docker-compose.yml:**
```yaml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: reforge
      POSTGRES_PASSWORD: reforge123
      POSTGRES_DB: reforge_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

**Tables created:**

| Table | Purpose |
|---|---|
| `users` | Stores user profile, weight, XP, level, title |
| `weight_logs` | One entry per weigh-in |
| `quests` | Quest definitions (title, type, XP reward, rarity) |
| `user_quests` | Daily quest assignments per user with progress |
| `food_logs` | Food photo logs with AI calorie/protein estimates |
| `xp_events` | Every XP gain recorded with reason |

---

### Data Models (SQLAlchemy)

Each table is defined as a Python class in `app/models/__init__.py`. SQLAlchemy maps these classes to database tables automatically.

**User model — the core:**
```python
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
    created_at = Column(DateTime, default=datetime.utcnow)
```

Every user starts at Level 1, 0 XP, with the title "Novice".

---

### API

FastAPI runs locally with:
```bash
uvicorn app.main:app --reload
```

Interactive API docs available at: http://127.0.0.1:8000/docs

**Endpoints built today:**

| Method | Endpoint | What it does |
|---|---|---|
| GET | `/` | Health check — confirms API is running |
| GET | `/health` | Returns `{"status": "ok"}` |
| POST | `/users/` | Creates a new user, logs starting weight |
| GET | `/users/{id}` | Returns user profile by ID |

**First user created:**
```json
{
  "id": 1,
  "name": "Fireball",
  "age": 25,
  "height_cm": 169.0,
  "current_weight": 75.0,
  "goal_weight": 62.0,
  "xp": 0,
  "level": 1,
  "title": "Novice"
}
```

---

### Issues encountered

| Problem | Cause | Fix |
|---|---|---|
| Homebrew Python broken | macOS 26 beta incompatibility with `ensurepip` | Used official Python.org installer |
| Flutter download kept failing | Google CDN HTTP/2 stream errors on large files | Used `wget -c` for resumable download |
| `Table already defined` SQLAlchemy error | `create_tables.py` was inside `app/` folder causing double import | Moved it to root directory |
| CocoaPods install failed | Mac's built-in Ruby 2.6 too old | Installed Ruby via Homebrew, then CocoaPods |

---

### What's next (Session 2)

- [ ] Quest engine — core logic that assigns daily quests per user
- [ ] XP service — awards XP on quest completion, handles level ups
- [ ] Weight logging endpoint
- [ ] Apple Health integration planning
- [ ] Flutter project setup and first screen

---

## Session 4 — August 24, 2026

### What we built

A large session covering four areas: fixing and extending food logging, replacing the static quest system with AI-generated quests, adding an AI Coach with real access to user data, and profile/settings support. Also fixed several correctness bugs surfaced while building and testing these features end-to-end.

---

### Food logging

- **Gemini prompt** (`app/services/ai_service.py`) now asks for `fat_g` and `carbs_g` alongside calories/protein, and explicitly instructs the model to reason about portion size/amount per item before estimating macros — accuracy depends on that intermediate step even though the amount itself isn't returned.
- **Food item names are now persisted.** `FoodLog.food_name` didn't exist before — the AI's `items` list was returned once on the logging response but never saved, so history always showed "Unknown meal." Now stored and returned as a proper `items` list on every endpoint that returns a `FoodLog`.
- **Manual entry** — `POST /food/log/manual` logs a meal without the AI pipeline: name + calories required, protein/fat/carbs and a photo optional. Marked `confirmed` immediately (confidence 1.0), awards the same +20 XP.
- **Photo serving** — `GET /food/images/{image_id}` streams a single photo's bytes; `_format_food_log` now includes `image_ids` so the app can build a detail view with all angles.
- **Delete** — `DELETE /food/log/{food_log_id}` removes a log and its photos.

### Quests — AI-generated, restricted to 5 categories

Quests used to be a random pick from a static seeded pool with no relationship to the user's level or state. Replaced with a hybrid system (`app/services/quest_service.py`):

- Restricted to exactly 5 categories: **walking, running, swimming, diet (calories or protein), hiking.**
- Gemini picks the categories + numeric targets for the day based on the user's level, recent weight/food/quest history, and even recent Coach conversation (so telling Coach "my knee hurts, no running" actually changes what gets generated). Fixed title/description templates render the wording; XP/rarity derived from the target.
- AI output is clamped to sane per-category ranges and validated; if the call fails or returns garbage, a deterministic level-based fallback generator fills the gap — quest generation can never 500 the dashboard.
- `POST /quests/{user_quest_id}/replace` — swap a specific quest for a new one, optionally targeting a specific category ("I don't want to run today, give me walking").
- **Auto-completion tied to real data:**
  - Protein quests ("hit Xg protein") auto-complete the moment today's confirmed food crosses the target, and auto-*undo* (XP revoked) if a food log is deleted and the total drops back below — but only for quests our system auto-completed, never overriding a quest the user completed by hand.
  - Calorie quests ("stay under X kcal") can only be judged once the day is over — `resolve_past_calorie_quests` runs whenever `/quests/today` is hit on a new day, checks the previous day's total against target, and auto-completes if the user stayed under.
- `POST /quests/uncomplete/{user_quest_id}` — manual undo via the dashboard's tick, reverses the XP (and can demote a level).

### Coach

New AI chat feature (`app/routes/coach.py`, `app/services/coach_service.py`) with real access to the user's level, weight history, recent meals with macros, and quest history — not a generic chatbot. Conversation history persists (`CoachMessage` table) and the last 20 turns are sent back on each reply for continuity.

### Profile / Settings

- `PATCH /users/{id}` — edit name/age/height/weight/goal weight; a weight change also logs a `WeightLog` entry so the Weight tab stays consistent.
- `POST` / `GET /users/{id}/photo` — avatar upload/serve, same byte-storage pattern as food photos.

### New shared services

- `app/services/gemini_client.py` — shared Gemini client setup + JSON-extraction helper, used by food analysis, quest generation, and Coach instead of duplicating the boilerplate three times.
- `app/services/user_context.py` — builds the "what does the AI know about this user" text block (profile, weight trend, recent meals, recent quests, recent Coach conversation), shared by both Coach and quest generation so a preference stated to Coach can influence quest generation too.

### Schema changes

| Table | Change |
|---|---|
| `food_logs` | added `food_name`, `estimated_fat`, `estimated_carbs` |
| `quests` | added `diet_metric` (`"calories"` / `"protein"`, only set for diet-type quests) |
| `user_quests` | added `auto_completed` (distinguishes system-driven completion from a manual tap) |
| `users` | added `avatar_data` (profile photo bytes) |
| `coach_messages` | new table — persisted Coach chat history |

No Alembic migrations exist yet — these were applied directly against the local Postgres container. A fresh DB via `create_tables.py` picks them up automatically.

### Bugs fixed this session

| Bug | Cause | Fix |
|---|---|---|
| `/food/history` returned 500 | Model gained `estimated_fat`/`estimated_carbs` columns but the live table was never migrated | Applied `ALTER TABLE` directly; noted that this project has no migration tooling |
| Meal names always "Unknown" | `food_name` was never persisted, and the API returned it in a shape (`food_name` string) the Flutter model didn't expect (`items` list) | Added the column, matched the response shape to what the frontend already parsed |
| Dashboard showed no quests on a new day | `assign_daily_quests` was never actually called from `/quests/today` — quests only got created via a separate, never-invoked `/quests/assign` endpoint | `/quests/today` now calls `assign_daily_quests` directly (already idempotent per day) |
| Level-up popup silently didn't fire | `leveled_up`/`new_level`/`new_title` were computed from the *first* XP award in a request, before a same-request quest auto-completion could award more XP and actually cross the threshold | Now computed from the user's level before vs. after all XP-affecting side effects in the request settle |

### What's next

- [ ] Alembic migrations (schema changes are currently applied by hand)
- [ ] Progress tracking for non-diet quest types (`UserQuest.progress_value` exists but nothing writes to it — workout/walk quests are still completed by an honesty-based tap, not measured data)
- [ ] Level-down handling in the UI when an auto-completed quest gets reversed

---

*Documentation updated: August 24, 2026 — Session 4 complete.*
