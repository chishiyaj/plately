# PLATELY V2 — MEMORY.md
> Paste this at the START of every new Claude chat alongside SKILLS.md and TASKS.md.
> Last updated: Session 33 — full source audit from disk.

---

## WHAT WE ARE BUILDING
Plately V2 — A Flutter mobile app for Android that helps students cook affordable, high-protein meals. Users scan or type ingredients, get AI recipe suggestions, see calories + protein, and track their cooking history.

**USP:** "Pre-cook macro awareness — know your protein and calories BEFORE you cook, not after."

---

## TECH STACK (VERIFIED — Session 33)

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) — Android target |
| Backend | Python Flask + dual-mode DB: PostgreSQL (prod) / SQLite (local) |
| AI Chat | OpenRouter — `google/gemma-3-27b-it:free` |
| AI Recipes | OpenRouter Gemma 3 27B — generates 5 custom recipes, 1hr DB-backed cache |
| Image Scan | OpenRouter Gemma 3 Vision — fallback chain (27b → 12b → 4-31b) |
| Auth | Firebase Auth (Email/Password + Google Sign-In) ✅ |
| Notifications | flutter_local_notifications — 5 dynamic scheduled + 1 cook-done one-shot |
| Prefs | SharedPreferences — UID-namespaced, daily macro reset on new day |
| Prod Server | gunicorn (Linux) / waitress (Windows) — wsgi.py auto-detects OS |
| Deploy | Railway — railway.json + Nixpacks, Neon PostgreSQL |

---

## DESIGN SYSTEM

| Token | Value |
|-------|-------|
| primaryDark | #043B3C |
| creamBg | #F0EEE9 |
| darkText | #043B3C |
| mutedText | #7A7A7A |
| green | #76CC4F |
| purple | #BA5CCC |
| yellow | #EABA1C |
| red | #D14444 |
| darkBg (dark mode) | #0A1414 |
| darkCard | #152020 |
| darkTextPrimary | #F0EEE9 |
| Font brand | Nunito |
| Font UI | DM Sans |

---

## SCREENS (ALL BUILT ✅)
1. `splash_screen.dart` — onboarding carousel
2. `login_screen.dart` — email + password + Google
3. `signup_screen.dart` — username + email + password + Google + email verification
4. `home_screen.dart` — greeting, hero CTA, calendar macro widget, macro rings, action row, suggested recipes, recent activity
5. `recipe_results_screen.dart` — grid, shimmer, filters, search bar, error state, offline banner
6. `recipe_detail_screen.dart` — ingredients/steps tabs, serving scaler, nutrition card, Ask AI FAB, share card, finish cooking
7. `favorites_screen.dart` — search bar, category filters, recipe grid
8. `history_screen.dart` — stats card, grouped entries, delete, Cook Again
9. `ai_chat_screen.dart` — chat bubbles, quick chips, initialPrompt, red error bubble for ERROR: prefix
10. `profile_screen.dart` — avatar, stats, goals card, dietary prefs, Display toggle (Light/Dark/System), settings
11. `pantry_screen.dart` — name/quantity/unit/always-stocked, SharedPreferences
12. `shopping_list_screen.dart` — auto from recipes, pantry cross-ref, Shopee deep-link
13. `ingredient_entry_screen.dart` — camera (permission_handler, error overlay, loading spinner, lifecycle retry) + type mode
14. `onboarding_goals_screen.dart` — body stats + fitness goal, Mifflin-St Jeor TDEE via /api/goals

---

## NAVIGATION
- Bottom nav: Home | Favorites | [Scan FAB] | AI Chat | Profile
- Shell tab indices: 0=Home, 1=Favorites, 2=AiChat, 3=Profile
- `MainShell.switchTab(n)` — static method

---

## API ENDPOINTS

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/scan | base64 → ingredients[] via Gemma vision |
| POST | /api/recipes | browse DB or AI-generate 5 recipes |
| GET | /api/recipe/\<id\> | recipe detail + nutrition + ingredients |
| POST | /api/chat | message → Gemma reply |
| POST | /api/goals | Mifflin-St Jeor TDEE |
| GET/POST | /api/favorites | get/add (includes ingredient list) |
| GET | /api/favorites/check/\<id\> | is saved? |
| DELETE | /api/favorites/\<id\> | unsave |
| GET/POST | /api/history | get/add history |
| GET | /api/history/stats | total_sessions, total_recipes, sessions_this_week |
| GET | /api/history/daily | ?user_id=&date=YYYY-MM-DD → daily macro summary |
| DELETE | /api/history/\<id\> | delete entry (requires user_id) |
| DELETE | /api/history | clear all |
| GET | /api/health | health check |

---

## DATABASE (Neon PostgreSQL prod / SQLite local)

Tables: `ingredients` (~84), `recipes` (~100), `recipe_ingredients`, `nutrition` (has cost_php), `history` (has calories_logged, protein_logged), `favorites`, `ai_recipe_cache`

Recipe filters (tags): `Asian | Italian | Vegetarian | Low-Cal | High-Protein | Filipino`

~100 seeded recipes including 20 Filipino staples + 40 regional Filipino + budget Asian.

---

## PACKAGES (pubspec.yaml — verified Session 33)

| Package | Purpose |
|---------|---------|
| `flutter_animate` | animations |
| `lucide_icons_flutter` | icons |
| `shimmer` | skeleton loading |
| `glassmorphism` | frosted glass |
| `camera` | viewfinder |
| `permission_handler: ^11.3.1` | camera permission (added S33) |
| `animations` | SharedAxisTransition |
| `flutter_svg` | Google G logo |
| `firebase_core`, `firebase_auth`, `google_sign_in` | auth |
| `flutter_local_notifications`, `timezone` | notifications |
| `cached_network_image` | recipe images |
| `flutter_markdown` | AI chat markdown |
| `fl_chart` | charts |
| `url_launcher` | Shopee links |
| `screenshot` + `share_plus` | share card |
| `package_info_plus` | version display |
| `image_picker`, `shared_preferences`, `sqflite`, `http`, `path` | core |

---

## CURRENT SETUP STATUS (Session 33)

| Item | Status |
|------|--------|
| flutter analyze | ✅ 0 issues |
| Firebase Auth (email + Google) | ✅ |
| google-services.json | ✅ |
| Font TTF files (6) | ✅ |
| Backend live on Railway | ✅ https://plately-production.up.railway.app |
| Neon DB connected + seeded | ✅ ~100 recipes |
| Landing page | ✅ https://chishiyaj.github.io/plately |
| cron-job.org keepalive | ✅ every 10 min |
| GitHub Actions CI/CD | ✅ distribute.yml |
| APK keystore | ✅ upload-keystore.jks |
| themeNotifier (ValueNotifier) | ✅ main.dart top-level |
| Dark mode themes + helpers | ✅ app_theme.dart |
| Theme toggle on Profile | ✅ Light/Dark/System pills |
| permission_handler in pubspec | ✅ added S33 |
| Camera permission flow | ✅ fixed S33 — explicit request, error overlay, lifecycle retry |
| AI chat error bubble (red) | ✅ fixed S33 |
| ai_chat_screen circleAlert icon | ✅ fixed S33 |
| history.py duplicate route | ✅ FIXED S33 — get_daily_history was duplicated, now clean |
| getRecipesResult() + error state | ✅ recipe_results_screen.dart |
| getDailyHistory() in api_service | ✅ |
| Calendar macro widget (home) | ✅ |
| Streak system | ✅ |
| Offline recipe cache (sqflite) | ✅ |
| Share card | ✅ |
| ₱ cost chips | ✅ |
| ALLOWED_ORIGINS Railway var | ⬜ still needs setting |
| Firebase App Distribution testers | ⬜ emails not added yet |

---

## API CONNECTION
`ApiService.baseUrl` reads from `--dart-define=PLATELY_API_URL` at build time.
- Emulator: `flutter run` → `http://10.0.2.2:5000`
- Physical device: `flutter run --dart-define=PLATELY_API_URL=http://192.168.x.x:5000`
- Production: `flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-production.up.railway.app`

---

## TEAM
| Name | Role |
|------|------|
| Marc | Frontend (Flutter) |
| Marco | Backend (Flask, DB) |
| Landon | AI & Data |
| Adrian | QA & Docs |
