# PLATELY V2 — PROJECT MEMORY
> Paste this at the START of every new Claude chat alongside SKILLS.md and TASKS.md.
> Last updated: Session 7 — audited directly from source files.

---

## WHAT WE ARE BUILDING
Plately V2 — A Flutter mobile app for Android that helps students cook affordable, high-protein meals. Users scan or type ingredients, get AI recipe suggestions, see calories + protein, and track their cooking history.

**USP:** "Pre-cook macro awareness — know your protein and calories BEFORE you cook, not after. Competitors (MyFitnessPal, Cronometer) scan cooked food to log what you already ate. Plately flips it: plan → cook → hit your goals."

---

## THIS IS A COMPLETE REWRITE
- V1 (plately-old/) = Android/Kotlin — SCRAPPED, do not reference.
- V2 (plately-v2/) = Flutter/Dart — THIS is the active project.

---

## TECH STACK (VERIFIED CURRENT — read from source)

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) — Android target |
| Backend | Python Flask + **dual-mode DB: PostgreSQL (prod) / SQLite (local)** |
| AI Chat | OpenRouter API — `google/gemma-3-27b-it:free` |
| AI Recipes | OpenRouter Gemma 3 27B — generates 5 custom recipes when ingredients provided |
| Image Scan | OpenRouter Gemma 3 Vision — fallback chain (27b → 12b → 4-31b) |
| Auth | Firebase Auth (Email/Password + Google Sign-In) — ✅ wired |
| Notifications | flutter_local_notifications — 3 scheduled + 1 one-shot (see below) |
| Prefs | SharedPreferences — UID-namespaced, daily macro reset on new day |
| Prod Server | waitress (Windows) / gunicorn (Linux) — wsgi.py auto-detects OS |
| Deploy config | railway.json present — Nixpacks builder, `python wsgi.py` start command |

**IMPORTANT:** Google Cloud Vision API is GONE. Scan uses OpenRouter Gemma vision model. No billing required.

---

## DESIGN SYSTEM

| Token | Value |
|-------|-------|
| primaryDark | #043B3C |
| creamBg | #F0EEE9 |
| darkText | #083F3F |
| mutedText | #7A7A7A |
| green | #76CC4F |
| purple | #BA5CCC |
| yellow | #EABA1C |
| red | #D14444 |
| Font brand | Nunito (logo/headings) |
| Font UI | DM Sans (all UI text) |

---

## SCREENS (ALL BUILT ✅)
1. `splash_screen.dart` — onboarding carousel (x3 slides)
2. `login_screen.dart` — email + password + Google
3. `signup_screen.dart` — username + email + password + Google + email verification
4. `home_screen.dart` — greeting, smart actions, suggested recipes, activity, links to Pantry
5. `recipe_results_screen.dart` — grid, filters (Asian/Italian/Vegetarian/Low-Cal/High-Protein/**Filipino**)
6. `recipe_detail_screen.dart` — ingredients tab + steps tab + serving size scaler + nutrition card + floating Ask AI pill FAB
7. `favorites_screen.dart` — search bar, category filters, recipe grid
8. `history_screen.dart` — stats card always visible (0s when empty), grouped by Today/Yesterday/Week/Older, conditional back button
9. `ai_chat_screen.dart` — chat bubbles, input bar, quick prompt chips, accepts `initialPrompt`
10. `profile_screen.dart` — avatar, dietary prefs, calorie goal progress bar, animated auto-calc toggle, Mifflin-St Jeor TDEE, color-coded goal buttons
11. `pantry_screen.dart` ✅ **NEW** — manage pantry items (name, quantity, unit), mark items as "always stocked", persisted via SharedPreferences
12. `shopping_list_screen.dart` ✅ **NEW** — auto-builds shopping list from selected recipes, cross-references pantry to skip stocked items, Shopee deep-link via url_launcher
13. `ingredient_entry_screen.dart` — camera scan mode + type mode, chip input

---

## NAVIGATION
Bottom nav: Home | Favorites | [Scan FAB center] | AI Chat | Profile
- Tab indices (shell): 0=Home, 1=Favorites, 2=AiChat, 3=Profile
- Nav bar indices: 0=Home, 1=Saved, 2=Scan(FAB), 3=AI, 4=Profile
- FAB opens `IngredientEntryScreen` (full-screen push over shell)
- `MainShell.switchTab(n)` — static method, used by HomeScreen to switch without push

---

## API ENDPOINTS (ALL WORKING ✅)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/scan | base64 image → ingredients[] via Gemma 3 vision |
| POST | /api/recipes | No ingredients → DB browse; with ingredients → AI generates 5 custom recipes |
| GET | /api/recipe/\<id\> | recipe detail + nutrition + ingredients |
| POST | /api/chat | message → AI reply (Gemma 3 27B) |
| POST | /api/goals | weight/height/age/goal/sex → TDEE targets (Mifflin-St Jeor) |
| GET/POST | /api/favorites | get/add favorites (response includes ingredient list) |
| GET | /api/favorites/check/\<id\> | is recipe saved? |
| DELETE | /api/favorites/\<id\> | remove favorite |
| GET/POST | /api/history | get/add history |
| GET | /api/history/stats | total_sessions, total_recipes, sessions_this_week |
| DELETE | /api/history/\<id\> | delete one entry (requires user_id) |
| DELETE | /api/history | clear all for user |
| GET | /api/health | health check — returns recipe count, env, service name |

**AI recipe caching:** Results cached in-memory by (ingredients + prefs) fingerprint for 1 hour (TTL = 3600s).

---

## DATABASE — Dual-mode PostgreSQL / SQLite (6 tables)

`database.py` auto-detects: if `DATABASE_URL` env var set → PostgreSQL (Render/Railway). Otherwise → SQLite at `backend/db/plately.db`.

Tables:
- `ingredients`: id, name — **~84 ingredients seeded** (see full list below)
- `recipes`: id, name, cook_time, difficulty, instructions, tags, **image_url** — **34 recipes seeded**
- `recipe_ingredients`: recipe_id, ingredient_id, amount
- `nutrition`: recipe_id, calories, protein, carbs, fat
- `history`: id, user_id, action_type, ingredient_names, recipe_count, timestamp
- `favorites`: id, user_id, recipe_id (UNIQUE constraint on user+recipe)

Indexes: `idx_history_user`, `idx_favorites_user`, `idx_history_ts`

**34 seeded recipes:**

*Core 14:*
Chicken Stir Fry, Egg Fried Rice, Tuna Pasta, Beef Bowl, Veggie Omelette, Garlic Shrimp Pasta, Tofu Scramble, Salmon with Garlic Rice, Pork Cabbage Stir Fry, Bacon and Egg Toast, Mushroom and Spinach Pasta, Coconut Milk Chicken, Potato and Egg Hash, Spicy Tuna Rice Bowl

*Filipino Staples (20 — tagged "Filipino"):*
Chicken Adobo, Pork Adobo, Sinangag, Tapsilog, Chicken Tinola, Sinigang na Baboy, Ginisang Monggo, Tortang Talong, Champorado, Arroz Caldo, Bistek Tagalog, Pork Nilaga, Pork Menudo, Chicken Afritada, Pancit Bihon, Lomi, Bicol Express, Kare-Kare, Sisig, Lugaw

**All recipe images:** Unsplash URLs stored in `image_url` column.

**Recipe filters (tags):** Asian, Italian, Vegetarian, Low-Cal, High-Protein, **Filipino**

---

## FOLDER STRUCTURE (ACTUAL — verified from disk)
```
plately-v2/
├── MEMORY.md / SKILLS.md / TASKS.md / TEAM_GUIDE.md
├── backend/
│   ├── app.py              ← Flask factory, structured logging, rate limiter, CORS, security headers
│   ├── database.py         ← Dual-mode PostgreSQL/SQLite, WAL, indexes, seed (34 recipes, ~84 ingredients)
│   ├── requirements.txt
│   ├── wsgi.py             ← waitress (Windows) / gunicorn (Linux) — auto-detects OS
│   ├── railway.json        ← Railway deploy config (Nixpacks, python wsgi.py)
│   ├── Procfile            ← gunicorn for Render
│   ├── _seed_data.py       ← Standalone seed script (run manually if needed)
│   ├── .env / .env.example
│   └── routes/
│       ├── scan.py         ← Gemma vision, partial ingredient matching, model fallback chain
│       ├── recipes.py      ← DB browse OR AI-generated recipes, 1hr cache, tag normaliser
│       ├── chat.py         ← Gemma 3 27B, system+user prompt merged
│       ├── goals.py        ← Mifflin-St Jeor TDEE
│       ├── favorites.py    ← includes full ingredient list in response
│       └── history.py      ← DELETE requires user_id
└── frontend/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart               ← skips splash for logged-in users
        ├── main_shell.dart         ← IndexedStack shell, static switchTab(), FAB at top:8
        ├── theme/app_theme.dart
        ├── screens/
        │   ├── home_screen.dart              ← Start pill hero, links to pantry_screen
        │   ├── recipe_results_screen.dart    ← real API, shimmer, Filipino filter
        │   ├── recipe_detail_screen.dart     ← serving scaler, Ask AI FAB, share
        │   ├── favorites_screen.dart         ← real API
        │   ├── history_screen.dart           ← unified session model, back button
        │   ├── ai_chat_screen.dart           ← accepts initialPrompt
        │   ├── profile_screen.dart           ← auto-calc, Mifflin-St Jeor, progress bar
        │   ├── pantry_screen.dart            ← pantry management, always-stocked flag
        │   ├── shopping_list_screen.dart     ← recipe→shopping list, pantry cross-ref, Shopee link
        │   ├── ingredient_entry_screen.dart
        │   ├── login_screen.dart
        │   ├── signup_screen.dart
        │   └── splash_screen.dart
        ├── widgets/
        │   ├── plately_logo.dart     ← PlatelyLogoTheme.onDark / onLight
        │   ├── google_g_logo.dart    ← Real 4-path inline SVG Google G
        │   ├── activity_row.dart     ← Shared Home + History, unified session model
        │   ├── recipe_card.dart
        │   ├── tap_scale.dart
        │   ├── ai_tip_card.dart
        │   └── bottom_nav.dart       ← Legacy (main_shell.dart handles nav now)
        ├── models/               ← recipe.dart, ingredient.dart, chat_message.dart
        ├── services/
        │   ├── api_service.dart        ← All HTTP, baseUrl currently = emulator (10.0.2.2:5000)
        │   ├── auth_service.dart       ← Firebase Auth, changePassword, signOut
        │   ├── notification_service.dart ← 3 scheduled + 1 one-shot notifications
        │   └── user_prefs_service.dart ← SharedPreferences name/email/goals/daily tracking
        └── utils/nutrition_calc.dart
```

---

## NOTIFICATIONS (actual — 3 scheduled + 1 one-shot)
- **Daily meal log reminder** — 8:00 PM — "Don't forget to log today!"
- **Protein goal reminder** — 1:00 PM — mid-day protein check
- **Cook streak alert** — 6:00 PM — only fires if no recipe cooked today
- **Cook done** — one-shot — fires when user finishes a recipe (channel: `plately_cooking`)

---

## PACKAGES (pubspec.yaml — verified)

| Package | Purpose |
|---------|---------|
| `flutter_animate` | chainable animations |
| `lucide_icons_flutter` | icons (not Material) |
| `shimmer` | skeleton loading |
| `glassmorphism` | frosted glass |
| `camera` | live camera viewfinder |
| `animations` | SharedAxisTransition |
| `flutter_svg` | Google G logo |
| `firebase_core`, `firebase_auth`, `google_sign_in` | auth |
| `flutter_local_notifications`, `timezone` | notifications |
| `cached_network_image` | recipe image URLs |
| `flutter_markdown` | markdown in AI chat responses (**present — NOT removed**) |
| `fl_chart` | macro dashboard bar chart |
| `url_launcher` | Shopee deep-links from shopping list |
| `screenshot` + `share_plus` | recipe share card |
| `image_picker`, `shared_preferences`, `sqflite`, `http`, `path` | core utilities |

---

## CURRENT SETUP STATUS (VERIFIED from source)

| Item | Status |
|------|--------|
| google-services.json | ✅ Present in frontend/android/app/ |
| Font TTF files | ✅ All 6 fonts in assets/fonts/ |
| Firebase Auth | ✅ Wired (email/password + Google) |
| OpenRouter AI Chat | ✅ Working — Gemma 3 27B |
| OpenRouter Scan | ✅ Coded — Gemma 3 vision, partial ingredient matching, fallback chain |
| OpenRouter AI Recipe Gen | ✅ Coded — Gemma 3 27B, 1hr cache, tag normaliser |
| Backend rate limiting | ✅ flask-limiter (200/min, 2000/hr) |
| Backend security headers | ✅ X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Cache-Control |
| Backend structured logging | ✅ timestamp/level/module format, request timing logged |
| Serving size scaler | ✅ ½x / 1x / 1.5x / 2x / 3x in recipe detail |
| Logout (real Firebase) | ✅ AuthService.signOut() |
| Change Password (Firebase) | ✅ Re-auth + updatePassword |
| Favorites include ingredients | ✅ Fixed in favorites.py |
| History DELETE secured | ✅ user_id required |
| flutter_local_notifications | ✅ Fully wired — 3 scheduled + cook-done one-shot |
| flutter_markdown | ✅ In pubspec (was incorrectly marked removed) |
| Pantry screen | ✅ Built — quantity/unit/always-stocked, SharedPreferences |
| Shopping list screen | ✅ Built — auto from recipes, pantry cross-ref, Shopee deep-link |
| fl_chart | ✅ In pubspec — macro dashboard |
| Recipe image URLs | ✅ Unsplash URLs in image_url column |
| Filipino recipes (20) | ✅ Seeded — tagged "Filipino" |
| DB dual-mode (PG + SQLite) | ✅ database.py auto-detects DATABASE_URL |
| railway.json / Procfile | ✅ Present — deploy config ready |
| Auth persistence | ✅ main.dart skips splash for logged-in users |
| flutter analyze | ✅ 0 issues |
| user_id isolation | ✅ FIXED S8 — all API calls use Firebase UID, no more 'default' |
| baseUrl dart-define | ✅ FIXED S8 — `--dart-define=PLATELY_API_URL=...` at build time |
| Filipino tag + filter | ✅ FIXED S8 — tag normaliser + Flutter filter chip |
| Chat rate limit | ✅ FIXED S8 — per Firebase UID, not per-IP |
| KeepAliveService | ✅ NEW S8 — pings /api/health every 9min, prevents cold starts |
| DEPLOY.md | ✅ NEW S8 — full Railway deploy + APK signing guide |
| Backend cloud deploy | ❌ Railway config ready — Marco needs to push + set env vars |
| APK signing | ❌ Keystore not generated yet — see DEPLOY.md Step 4 |

---

## API CONNECTION
`ApiService.baseUrl` reads from `--dart-define=PLATELY_API_URL` at build time.
- Local dev (emulator): `flutter run` → defaults to `http://10.0.2.2:5000`
- Local dev (physical): `flutter run --dart-define=PLATELY_API_URL=http://192.168.100.15:5000`
- Production APK: `flutter build apk --release --dart-define=PLATELY_API_URL=https://YOUR.railway.app`

---

## TEAM
| Name | Role |
|------|------|
| Marc | Frontend (Flutter) |
| Marco | Backend (Flask, DB) |
| Landon | AI & Data (OpenRouter, scan, recipe gen) |
| Adrian | QA & Docs |

## GITHUB
```
main → stable only
dev  → integration
feature/frontend-* | feature/backend-* | feature/ai-*
```
