# Reforge

An AI-powered fitness RPG. Real life becomes a game — log food, complete quests, hit daily targets, level up.

This is a monorepo combining the two previously separate projects:

```
reforge-mono/
├── backend/    FastAPI + PostgreSQL + Gemini — see backend/REFORGE_DOCS.md
└── frontend/   Flutter (iOS) client         — see frontend/README.md
```

Each side keeps its own living doc with full session-by-session history of what was built, why, and what's next. This root README is just the map.

---

## Quickstart

**Backend:**
```bash
cd backend
cp .env.example .env   # fill in GEMINI_API_KEY
docker-compose up -d   # starts Postgres
python -m venv .venv && source .venv/bin/activate
pip install fastapi uvicorn sqlalchemy psycopg2-binary alembic pydantic python-dotenv google-genai
python create_tables.py
uvicorn app.main:app --reload
```

**Frontend:**
```bash
cd frontend
flutter pub get
flutter run
```

The app is hardcoded to talk to `http://127.0.0.1:8000` and to a single user (`id=1`) — there's no signup/login flow yet.

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (iOS) |
| Backend API | FastAPI (Python) |
| Database | PostgreSQL (Docker locally) |
| AI (food analysis, quest generation, Coach) | Google Gemini |

---

## Note on history

This repo starts fresh as of the merge into a monorepo — it does not import the full commit history of the two original repos (which predate this structure and, in the backend's case, had a committed `.env` early on that we didn't want carried forward). Each original repo still exists locally with its own history if that's ever needed.
