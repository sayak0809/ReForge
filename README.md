# Reforge

An AI-powered fitness RPG. Real life becomes a game — log food, complete quests, hit daily targets, level up.

**Status: deployed and in a small friends beta.** Backend live at `https://reforge-production-96f9.up.railway.app`. The app runs on both iOS and Android and has a real onboarding flow — no hardcoded test user anymore.

This is a monorepo combining the two previously separate projects:

```
reforge-mono/
├── backend/    FastAPI + PostgreSQL + Gemini — see backend/REFORGE_DOCS.md
└── frontend/   Flutter client (iOS + Android) — see frontend/README.md
```

Each side keeps its own living doc with full session-by-session history of what was built, why, and what's next. This root README is just the map.

---

## Quickstart

**Backend (local dev):**
```bash
cd backend
cp .env.example .env   # fill in GEMINI_API_KEY
docker-compose up -d   # starts Postgres
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python create_tables.py
uvicorn app.main:app --reload
```

**Frontend**, pointed at the live deployed backend (no need to run one locally):
```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=https://reforge-production-96f9.up.railway.app
```

Swap that URL for `http://127.0.0.1:8000` (or a LAN IP) to test against a locally-run backend instead.

**Deploying the backend**: pushes to `main` do *not* currently auto-deploy on Railway (that connection was never fully wired up) — deploy manually with `railway up --service ReForge` from `backend/` after logging in with `railway login`.

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (iOS + Android) |
| Backend API | FastAPI (Python), deployed on Railway |
| Database | PostgreSQL (Railway-managed in prod, Docker locally) |
| AI (food analysis, quest generation, Coach) | Google Gemini (free tier — 20 requests/day shared across all users; needs billing enabled before a wider beta) |

---

## Note on history

This repo starts fresh as of the merge into a monorepo — it does not import the full commit history of the two original repos (which predate this structure and, in the backend's case, had a committed `.env` early on that we didn't want carried forward). Each original repo still exists locally with its own history if that's ever needed.
