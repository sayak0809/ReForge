# Reforge — Frontend

> A living document updated at the end of every build session, mirroring the backend's `REFORGE_DOCS.md`.

Reforge is an AI-powered fitness RPG. This is the Flutter client (iOS + Android) — it talks to the FastAPI backend, which does all the actual logic (AI food analysis, quest generation, Coach, XP/leveling). Live backend: `https://reforge-production-96f9.up.railway.app`.

---

## Running it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://reforge-production-96f9.up.railway.app
```

`API_BASE_URL` (`ApiService._baseUrl`) defaults to `http://127.0.0.1:8000` if omitted — only useful when the backend is also running locally on the same machine as the app (e.g. an iOS simulator on the same Mac). For a real device, always pass `--dart-define` explicitly, pointed at either the deployed backend above or a reachable local one.

Building for distribution works the same way:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://reforge-production-96f9.up.railway.app
```

There's no login/signup screen requiring a password — first launch runs an onboarding flow (profile setup + a short feature walkthrough) that creates a real backend account and stores its id locally via `shared_preferences`. Nothing is hardcoded to a single user anymore.

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

## Session 6 — August 24, 2026

### What we built

Turned this from "an app I run in a simulator" into something two real friends could actually install — a proper onboarding flow, a configurable backend URL, real iOS/Android distribution, and a few polish fixes surfaced by that first round of real use.

### Onboarding — no more hardcoded user

`ApiService.userId` was `static const int userId = 1` since the very first session. Now backed by `shared_preferences`: `ApiService.loadUserId()` restores it at startup (`main()` is `async` now), and a new `lib/screens/onboarding_screen.dart` — a button-driven `PageView` (setup form asking for first name/age/height/weight/goal weight, then 5 walkthrough slides explaining quests/food logging/Coach/trophies) — creates a real account via `ApiService.createUser()` on first launch and persists the returned id. `main.dart` gained a small `AppRoot` wrapper that shows onboarding or the main app depending on whether a user id is already stored, swapped via a callback (no circular import between `main.dart` and the onboarding screen).

### Configurable API base URL

`ApiService._baseUrl` was a hardcoded `http://127.0.0.1:8000` — meaning the app could only ever talk to a backend on the *same device* as the app, which is fine for a simulator but breaks completely for a real phone. Now reads `String.fromEnvironment('API_BASE_URL', ...)`, set at build time via `--dart-define`. Same mechanism works whether pointing at a LAN IP for same-WiFi testing or (what we ended up using) the deployed Railway URL.

### Real device installs

- **Android**: the default Flutter-scaffolded `AndroidManifest.xml` had zero `<uses-permission>` entries — no `INTERNET` permission means Android silently blocks all network access, which would have made every API call fail on a real device (unlike iOS, which doesn't require declaring network access at all). Added `INTERNET` and `CAMERA`. First successful `flutter build apk --release` produced a real, working, installable APK.
- **iOS**: the bundle ID was still the Flutter-scaffold default `com.example.reforge` — Apple's free/personal-team code signing outright rejects any `com.example.*` bundle ID. Changed to `com.sayak0809.reforge`. With that fixed, free-tier signing (Xcode → Signing & Capabilities → Personal Team) successfully installed the app directly onto a real iPhone over cable (`flutter run --release --dart-define=...`), after also enabling Developer Mode on the device (`Settings → Privacy & Security → Developer Mode`).
- **Remote iOS distribution investigated and ruled out for now**: ad-hoc IPA export + Diawi-style OTA install links require the *paid* Apple Developer Program ($99/yr) — a free Personal Team cannot create ad-hoc provisioning profiles at all, regardless of whether the target device's UDID is known. For a fully remote iPhone tester, the real options are: the friend builds/runs on their own Mac if they have one, or paying for the Developer Program (which also unlocks TestFlight, the actually-good way to do this).

### Polish from first real use

- **Keyboard couldn't be dismissed** on Coach or manual food entry after an error fired mid-typing — neither screen had tap-outside-to-dismiss wired up. Fixed on both with the standard `GestureDetector(onTap: () => FocusScope.of(context).unfocus())` wrap.
- **Trophy tier list** — tapping the dashboard trophy now opens `lib/screens/trophy_tiers_screen.dart`, showing all 6 tiers (Novice → Legend) with level ranges, XP required to unlock each, and the current tier highlighted. Numbers are hardcoded in Dart to mirror the backend's `_xp_required_for_level` formula exactly (triangular number × 100) — no API call needed since it's pure static game data.

### What's next

- [ ] Level-*down* still isn't shown anywhere in the UI
- [ ] No real progress tracking for non-diet quests (still an honesty tap)
- [ ] Remote iOS distribution is unresolved without paying for the Apple Developer Program

---

*Documentation updated: August 24, 2026 — Session 6 complete.*
