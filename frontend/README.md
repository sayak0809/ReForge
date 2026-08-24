# Reforge — Frontend

> A living document updated at the end of every build session, mirroring the backend's `REFORGE_DOCS.md`.

Reforge is an AI-powered fitness RPG. This is the Flutter (iOS) client — it talks to the FastAPI backend in the sibling `reforge-backend` repo, which does all the actual logic (AI food analysis, quest generation, Coach, XP/leveling).

---

## Running it

```bash
flutter pub get
flutter run
```

Points at `http://127.0.0.1:8000` by default (`ApiService._baseUrl`). The backend must be running (`uvicorn app.main:app --reload` from `reforge-backend`) with its Postgres container up (`docker-compose up -d`).

There's no login/signup flow — the app is hardcoded to a single user, `ApiService.userId = 1`.

---

## Structure

```
lib/
├── main.dart              ← App entry, theme, bottom nav (4 tabs)
├── models/                ← Plain Dart classes parsed from API JSON
├── screens/
│   ├── dashboard_screen.dart        ← Home: XP/level header, trophy, today's quests
│   ├── coach_screen.dart            ← AI chat
│   ├── weight_screen.dart           ← Weight log + chart
│   ├── food_screen.dart             ← Meal history, camera/manual logging
│   ├── food_detail_screen.dart      ← Single meal: photos + full macros
│   ├── manual_food_entry_screen.dart← Log a meal without the camera
│   └── settings_screen.dart         ← Profile edit + avatar upload
├── services/api_service.dart        ← All backend HTTP calls
├── theme/app_colors.dart            ← Single source of truth for the color palette
└── widgets/
    ├── trophy_badge.dart            ← Tiered trophy (Novice → Legend)
    └── level_up_dialog.dart         ← Shared level-up celebration
```

---

## Session 5 — August 24, 2026

### What we built

Four Dashboard-adjacent features plus a full visual re-theme, on top of the existing 3-screen app (Dashboard, Weight, Food) from Session 4.

### New screens

- **Coach** — chat UI with persisted history, talks to the backend's Coach endpoint.
- **Settings** — profile photo upload + edit name/age/height/weight/goal weight.
- **Food Detail** — tap a meal to see its photo(s) (swipeable) and full macro breakdown.
- **Manual Food Entry** — log a meal by typing name/calories (macros optional) instead of photographing it; reachable from the Food tab's FAB alongside the two AI photo options.

### Quests on the Dashboard

- Swipe-to-delete-style **swap icon** on each quest card opens a bottom sheet to replace it — "Surprise me" or a specific category.
- The completed checkmark is now tappable to **undo** a quest (reverses the XP via the backend).
- A small ✨ badge marks quests the system auto-completed from logged food, distinct from ones you ticked yourself.

### Trophies + level-up celebration

- `TrophyBadge` — six tiers (Novice → Walker → Runner → Athlete → Champion → Legend) matching the backend's title thresholds, each visually richer than the last (plain outline → bronze → silver → emerald → gold → glowing gradient + sparkle).
- Shown on the Dashboard header (next to the user's profile photo) and, bigger, in a `TrophyReveal` pop-in animation inside the level-up dialog.
- The level-up dialog itself was extracted into a shared `showLevelUpDialog()` so it fires consistently from every XP-earning action (completing a quest, logging food, logging weight) — previously only the quest checkbox tap showed it, so leveling up via food or weight logging was silent.

### Full re-theme: white + classy green

Replaced the original dark/gold theme app-wide. `lib/theme/app_colors.dart` is the single palette source (background, surface, primary green, text tiers, rarity colors, macro-nutrient accents, trophy tiers) — every screen was migrated off hardcoded hex literals. Added `google_fonts` and set **Manrope** as the app-wide font via `ThemeData.textTheme`.

### Bugs fixed this session

| Bug | Cause | Fix |
|---|---|---|
| Card/tile borders crashed the app | Flutter disallows `borderRadius` on a `Border` with non-uniform side colors (a full ring + a differently-colored accent side) | Dropped to a single accent-colored side + a subtle shadow for definition, matching the pattern that already worked |
| Bottom nav showed no labels and a stray colored background | Flutter defaults `BottomNavigationBar` to `shifting` type once there are 4+ tabs (added a 4th tab, Coach, this session) | Explicit `type: BottomNavigationBarType.fixed` |
| "Needs another photo" dialog never appeared | Checked `result['needs_more_photos']` / `result['food_log_id']`, but the backend returns `needs_better_photo` nested under `result['food_log']['id']` | Fixed both the key name and the nested path |
| Level-up popup silently didn't fire from food/weight logging | Those screens never read `leveled_up` from the API response at all — only the dashboard's quest-tap handler did | Centralized into `showLevelUpDialog()`, wired into all three XP-earning flows |

### What's next

- [ ] No real auth/multi-user support — still hardcoded to `userId = 1`
- [ ] Level-*down* isn't shown anywhere in the UI (e.g. undoing a quest can drop a level silently)
- [ ] Non-diet quest types (walking/running/swimming/hiking) are completed by an honesty tap — no real progress tracking against `target_value`

---

*Documentation updated: August 24, 2026 — Session 5 complete.*
