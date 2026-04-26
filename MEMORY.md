# PLATELY V2 — PROJECT MEMORY

> Paste this at the START of every new Claude chat. This is the project brain.

## WHAT WE ARE BUILDING

Plately V2 — A Flutter mobile app for Android that helps students cook affordable, high-protein meals. Users scan or type ingredients, get AI recipe suggestions, see calories + protein, and track their cooking history.

## USP

"Fast, free, high-protein meal generator for students — snap ingredients, get recipes in seconds."

## THIS IS A COMPLETE REWRITE

- V1 (plately-old/) = Android/Kotlin, SCRAPPED. Do not reference it.
- V2 (plately-v2/) = Flutter/Dart, THIS is the active project.
- V1 is archived only. All work happens in plately-v2/.

## TECH STACK

LayerTechFrontendFlutter (Dart) — Android targetBackendPython Flask + SQLiteAI ChatOpenRouter API (free tier, Mistral-7B)Image ScanGoogle Cloud Vision API (1000 req/mo free)AuthFirebase Auth (Google Sign-In)

## DESIGN SYSTEM (from Figma)

TokenValuePrimary dark#043B3C (dark teal)Cream bg#F0EEE9 (warm cream)Dark text#083F3FMuted text#7A7A7AGreen accent#76CC4F / #73CA4CPurple tag#BA5CCCYellow tip#EABA1CFont brandNunito (logo/headings)Font UIDM Sans (all UI text)

## SCREENS (in order)

 1. Splash x3 (onboarding carousel — Scan / Discover / Eat Smarter)
 2. Login (email + password + Google)
 3. Sign Up (username + email + password + Google)
 4. Dashboard/Home (greeting, smart actions, suggested recipes, activity)
 5. Recipe Results (grid, filters: Asian/Italian/Vegetarian/Low-Cal)
 6. Recipe Instructions (ingredients tab — hero image, macros, AI tip)
 7. Recipe Steps (steps tab — numbered steps, AI tip, finish cooking)
 8. Favorites (search bar, category filters, recipe grid)
 9. History / Your Activity (stats card, grouped by Today/Yesterday/Week/Older)
10. AI Chat / Ask Plately (chat bubbles, input bar)
11. Profile (avatar, dietary prefs, calorie goal progress, account settings)

## NAVIGATION

Bottom nav: Home | Favorites | \[Scan FAB center\] | AI Chat | Profile (The center FAB is the gradient teal scan button)

## API ENDPOINTS

MethodEndpointPurposePOST/api/scanimage_base64 → ingredients\[\]POST/api/recipesingredients\[\] → recipes\[\]GET/api/recipe/recipe detail + nutritionPOST/api/chatmessage → AI reply (OpenRouter)POST/api/goalsweight/height/age/goal → targets

## DATABASE (SQLite)

- ingredients: id, name
- recipes: id, name, cook_time, difficulty, instructions
- recipe_ingredients: recipe_id, ingredient_id
- nutrition: recipe_id, calories, protein, carbs, fat
- history: id, user_id, action_type, ingredient_names, recipe_count, timestamp
- favorites: id, user_id, recipe_id

## FOLDER STRUCTURE

```
plately-v2/
├── MEMORY.md          ← THIS FILE — paste at start of every chat
├── SKILLS.md          ← paste alongside MEMORY.md
├── README.md
├── docs/
│   └── API_CONTRACT.md
├── frontend/          ← Flutter project root (run flutter create here)
│   └── lib/
│       ├── main.dart
│       ├── theme/
│       │   └── app_theme.dart
│       ├── screens/
│       │   ├── splash_screen.dart         (onboarding 3-page carousel)
│       │   ├── login_screen.dart
│       │   ├── signup_screen.dart
│       │   ├── home_screen.dart           (dashboard)
│       │   ├── recipe_results_screen.dart
│       │   ├── recipe_detail_screen.dart  (ingredients + steps tabs)
│       │   ├── favorites_screen.dart
│       │   ├── history_screen.dart
│       │   ├── ai_chat_screen.dart
│       │   └── profile_screen.dart
│       ├── widgets/
│       │   ├── recipe_card.dart
│       │   ├── bottom_nav.dart
│       │   ├── ai_tip_card.dart
│       │   └── activity_row.dart
│       ├── models/
│       │   ├── recipe.dart
│       │   ├── ingredient.dart
│       │   └── chat_message.dart
│       ├── services/
│       │   ├── api_service.dart
│       │   └── auth_service.dart
│       └── utils/
│           └── nutrition_calc.dart
└── backend/
    ├── app.py
    ├── database.py
    ├── requirements.txt
    ├── .env               ← NEVER commit (API keys)
    ├── db/
    │   └── plately.db
    └── routes/
```
    ├── scan.py
    ├── recipes.py
    ├── chat.py
    └── goals.py
```

```

## CURRENT STATUS

- \[x\] plately-old/ renamed → archived
- \[x\] plately-v2/ folder structure created
- [x] MEMORY.md + SKILLS.md (god tier) written
- [x] main.dart scaffold
- [x] app_theme.dart with design tokens
- [x] All 10 screens fully coded (splash/login/signup/home/results/detail/favorites/history/ai_chat/profile)
- [x] All widgets (recipe_card, bottom_nav, ai_tip_card, activity_row)
- [x] Models: recipe.dart, ingredient.dart, chat_message.dart
- [x] Services: api_service.dart, auth_service.dart
- [x] Utils: nutrition_calc.dart (Mifflin-St Jeor)
- [x] pubspec.yaml with dependencies + font declarations
- [x] assets/fonts/ and assets/images/ folders created
- [ ] flutter create . run in frontend/ (initializes Android project files)
- [ ] Font TTF files downloaded → assets/fonts/
- [ ] flutter pub get
- [ ] Backend routes implemented (Flask)
- [ ] API connected to Flutter (replace mock data)
- [ ] Firebase Auth wired up
- [ ] Demo ready

## NEXT STEPS (in order)
1. cd plately-v2/frontend && flutter create . --org com.plately --project-name plately_v2
2. Download Nunito + DM Sans from fonts.google.com → put TTF in assets/fonts/
3. flutter pub get
4. flutter run (test on emulator)
5. Build backend routes

## TEAM (4 members)

- Member 1: Frontend (Flutter screens, navigation, UI)
- Member 2: Backend (Flask routes, SQLite, seeding)
- Member 3: AI & Data (OpenRouter, Vision API, ingredient matching)
- Member 4: QA & Docs (testing, GitHub PRs, demo video)

## GITHUB BRANCHING
```
main → stable only dev → integration feature/frontend-\* | feature/backend-\* | feature/ai-\* → per task

## EMULATOR CONNECTION

Android emulator → Flask: <http://10.0.2.2:5000>Physical device → Flask: use your PC's local IP (e.g. <http://192.168.x.x:5000>)

## KEY DECISIONS

- SQLite over Firebase for data (simpler MVP)
- Firebase Auth for Google Sign-In only
- Image scan fills ingredient input only (not direct recipe generation)
- AI chat is OpenRouter Mistral-7B free tier
- No meal planner, no social, no barcode scanner in MVP
- Mifflin-St Jeor formula for TDEE/calorie goals
