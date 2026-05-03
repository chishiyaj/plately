# PLATELY V2 — PROJECT MEMORY
> Paste this at the START of every new Claude chat alongside SKILLS.md and TASKS.md.

---

## WHAT WE ARE BUILDING
Plately V2 — A Flutter mobile app for Android that helps students cook affordable, high-protein meals. Users scan or type ingredients, get AI recipe suggestions, see calories + protein, and track their cooking history.

**USP:** "Pre-cook macro awareness — know your protein and calories BEFORE you cook, not after. Competitors (MyFitnessPal, Cronometer) scan cooked food to log what you already ate. Plately flips it: plan → cook → hit your goals."

---

## THIS IS A COMPLETE REWRITE
- V1 (plately-old/) = Android/Kotlin — SCRAPPED, do not reference.
- V2 (plately-v2/) = Flutter/Dart — THIS is the active project.

---

## TECH STACK (VERIFIED CURRENT)

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) — Android target |
| Backend | Python Flask + SQLite |
| AI Chat | OpenRouter API — `google/gemma-3-27b-it:free` |
| Image Scan | OpenRouter Gemma 3 Vision (FREE — Google Vision was SCRAPPED) |
| Auth | Firebase Auth (Email/Password + Google Sign-In) |
| Notifications | flutter_local_notifications — daily reminders + cook-done (fully wired) |
| Prefs | SharedPreferences — UID-namespaced, daily macro reset on new day |

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
1. Splash x3 — onboarding carousel
2. Login — email + password + Google
3. Sign Up — username + email + password + Google + email verification
4. Home/Dashboard — greeting, smart actions, suggested recipes, activity
5. Recipe Results — grid, filters (Asian/Italian/Vegetarian/Low-Cal/High-Protein)
6. Recipe Detail — ingredients tab + steps tab + serving size scaler + nutrition card
7. Favorites — search bar, category filters, recipe grid
8. History — stats card always visible, grouped by Today/Yesterday/Week/Older
9. AI Chat — chat bubbles, input bar, quick prompt chips
10. Profile — avatar, dietary prefs, calorie goal progress, edit goals w/ Mifflin-St Jeor auto-calc

**Extra screen:** `ingredient_entry_screen.dart` — camera scan mode + type mode, chip input

---

## NAVIGATION
Bottom nav: Home | Favorites | [Scan FAB center] | AI Chat | Profile
FAB opens `IngredientEntryScreen` (not a nav tab — pushes over shell)

---

## API ENDPOINTS (ALL WORKING ✅)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/scan | base64 image → ingredients[] via Gemma 3 vision |
| POST | /api/recipes | ingredients[] → recipes[] |
| GET | /api/recipe/\<id\> | recipe detail + nutrition + ingredients |
| POST | /api/chat | message → AI reply (Gemma 3) |
| POST | /api/goals | weight/height/age/goal/sex → TDEE targets |
| GET/POST | /api/favorites | get/add favorites |
| GET | /api/favorites/check/\<id\> | is recipe saved? |
| DELETE | /api/favorites/\<id\> | remove favorite |
| GET/POST | /api/history | get/add history |
| GET | /api/history/stats | total_sessions, total_recipes, sessions_this_week |
| DELETE | /api/history/\<id\> | delete one entry (requires user_id) |
| DELETE | /api/history | clear all for user |
| GET | /api/health | health check (exempt from rate limit) |

---

## DATABASE (SQLite — 6 tables)
- ingredients: id, name (44 ingredients seeded)
- recipes: id, name, cook_time, difficulty, instructions, tags (14 recipes seeded)
- recipe_ingredients: recipe_id, ingredient_id, amount
- nutrition: recipe_id, calories, protein, carbs, fat
- history: id, user_id, action_type, ingredient_names, recipe_count, timestamp
- favorites: id, user_id, recipe_id

**14 seeded recipes:** Chicken Stir Fry, Egg Fried Rice, Tuna Pasta, Beef Bowl, Veggie Omelette, Garlic Shrimp Pasta, Tofu Scramble, Salmon with Garlic Rice, Pork Cabbage Stir Fry, Bacon and Egg Toast, Mushroom and Spinach Pasta, Coconut Milk Chicken, Potato and Egg Hash, Spicy Tuna Rice Bowl

---

## FOLDER STRUCTURE (ACTUAL)
```
plately-v2/
├── MEMORY.md
├── SKILLS.md
├── TASKS.md
├── TEAM_GUIDE.md
├── backend/
│   ├── app.py              ← Flask app factory, rate limiter, CORS, security headers
│   ├── database.py         ← Thread-safe SQLite, WAL mode, seed
│   ├── requirements.txt
│   ├── wsgi.py             ← Production entry point (gunicorn)
│   ├── .env                ← Keys here (never commit)
│   └── routes/
│       ├── scan.py         ← Gemma vision scan
│       ├── recipes.py
│       ├── chat.py         ← Gemma 3 chat
│       ├── goals.py        ← Mifflin-St Jeor TDEE
│       ├── favorites.py
│       └── history.py
└── frontend/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── main_shell.dart       ← IndexedStack bottom nav shell
        ├── theme/app_theme.dart
        ├── screens/              ← All 10 screens + ingredient_entry_screen
        ├── widgets/
        │   ├── plately_logo.dart     ← PlatelyLogoTheme.onDark / onLight — ONLY logo definition
        │   ├── google_g_logo.dart    ← Real SVG Google G — used in login/signup
        │   ├── activity_row.dart     ← Shared by Home + History — zero duplication
        │   ├── recipe_card.dart
        │   ├── tap_scale.dart
        │   ├── ai_tip_card.dart
        │   └── bottom_nav.dart       ← Legacy, replaced by main_shell.dart nav
        ├── models/               ← recipe.dart, ingredient.dart, chat_message.dart
        ├── services/
        │   ├── api_service.dart  ← All HTTP calls, baseUrl switch for demo
        │   └── auth_service.dart ← Firebase Auth, changePassword, signOut
        └── utils/nutrition_calc.dart
```

---

## CURRENT SETUP STATUS (VERIFIED)

| Item | Status |
|------|--------|
| google-services.json | ✅ Present in frontend/android/app/ |
| Font TTF files | ✅ All 6 fonts in assets/fonts/ |
| Firebase Auth | ✅ Wired (email/password + Google) |
| OpenRouter AI Chat | ✅ Working — Gemma 3 27B |
| OpenRouter Scan | ✅ Coded — Gemma 3 vision with model fallback chain |
| Backend rate limiting | ✅ flask-limiter (200/min, 2000/hr) |
| Backend security headers | ✅ X-Content-Type-Options, X-Frame-Options, etc. |
| Serving size scaler | ✅ ½x / 1x / 1.5x / 2x / 3x in recipe detail |
| Logout (real Firebase) | ✅ AuthService.signOut() |
| Change Password (Firebase) | ✅ Re-auth + updatePassword |
| Favorites include ingredients | ✅ Fixed in favorites.py |
| History DELETE secured | ✅ user_id required |
| flutter_local_notifications | ✅ Fully wired — daily reminders + cook-done one-shot |
| flutter_markdown | ❌ REMOVED from pubspec (was unused) |
| Backend cloud deploy | ❌ Still localhost — Railway deploy pending |
| Auth persistence | ✅ main.dart skips splash for logged-in users |

---

## API CONNECTION (IMPORTANT)
`ApiService.baseUrl` in `frontend/lib/services/api_service.dart`:
- Emulator: `http://10.0.2.2:5000`
- Physical phone (current): `http://192.168.100.15:5000`
- Production (pending): Railway.app URL

---

## TEAM
| Name | Role |
|------|------|
| Marc | Frontend (Flutter) |
| Marco | Backend (Flask, SQLite) |
| Landon | AI & Data (OpenRouter, scan) |
| Adrian | QA & Docs |

## GITHUB
```
main → stable only
dev  → integration
feature/frontend-* | feature/backend-* | feature/ai-*
```
