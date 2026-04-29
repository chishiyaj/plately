# 🍽️ PLATELY V2 — TEAM GUIDE
> **UPDATED — Full Assessment Pass 3**
> Read YOUR section only. Follow it step by step.

---

## 👥 TEAM ROLES

| Name   | Role      | Responsibility                          |
|--------|-----------|------------------------------------------|
| Marc   | Frontend  | Flutter screens, UI, API connection      |
| Marco  | Backend   | Flask routes, SQLite, favorites, history |
| Landon | AI & Data | OpenRouter chat, Google Vision scan      |
| Adrian | QA & Docs | Testing every screen, README, bug report |

---

## ⚙️ ONE-TIME SETUP (ALL MEMBERS DO THIS)

### STEP 1 — Install Git
https://git-scm.com/downloads — install with default settings.

### STEP 2 — Clone the repo
Open PowerShell or any terminal:
```
git clone https://github.com/chishiyaj/plately.git
cd plately
git checkout dev
```

### STEP 3 — Set your Git identity (one time only)
```
git config --global user.email "your-github-email@gmail.com"
git config --global user.name "YourName"
```

---

## 🧠 EVERY CLAUDE SESSION — ALL MEMBERS

Paste this at the very top of EVERY new Claude chat before anything else:

```
NOTE: I am [Your Name], [Your Role] for Plately V2.
My local project path is: [your path here, e.g. C:\Users\marco\plately]

[Paste full MEMORY.md contents here]
[Paste full SKILLS.md contents here]
```

---

## 🔁 RELAY ORDER

```
Marc → push → tell Marco
Marco → push → tell Landon
Landon → push → tell Adrian
Adrian → test → push → done
```

### Before EVERY session:
```
git checkout dev
git pull
```

### After EVERY session:
```
git add .
git commit -m "yourname - what you did

- Built: what you added
- Changed: what you modified
- Notes: what next member needs to know"
git push
```

---

## 📊 TRUE PROJECT STATUS (as of Pass 3)

### ✅ FULLY DONE — Backend
- Flask app, CORS, blueprints registered
- POST /api/recipes — ingredient matching → recipes
- GET  /api/recipe/<id> — full detail + ingredients
- POST /api/scan — Vision API or mock fallback
- POST /api/chat — OpenRouter Mistral-7B or mock fallback
- POST /api/goals — Mifflin-St Jeor TDEE calculator
- GET/POST /api/favorites — ✅ NEW
- GET /api/favorites/check/<id> — ✅ NEW
- DELETE /api/favorites/<id> — ✅ NEW
- GET/POST /api/history — ✅ NEW
- GET /api/history/stats — ✅ NEW
- SQLite: all 6 tables, 6 seeded recipes, 22 ingredients

### ✅ FULLY DONE — Frontend (Marc)
- All 10 screens: Splash, Login, SignUp, Home, Results, Detail, Favorites, History, AI Chat, Profile
- MainShell with real bottom nav (IndexedStack, no rebuilds)
- IngredientEntryScreen (camera scan + type mode, chip input)
- Home: loads real recipes from API, real history
- Favorites: loads from API, search + filter working
- History: loads from API, grouped by date, real stats card
- Recipe Detail: loads real recipe, ingredients checklist, steps, nutrition
- ♥ Heart button: loads real favorite state, persists to backend ✅ NEW
- "Finish Cooking": logs to backend history + increments local count ✅ NEW
- Profile: Edit profile, goals, log calories — all save to SharedPrefs
- Profile recipe count: syncs from /api/history/stats ✅ NEW
- UserPrefsService.incrementRecipeCount() — exists ✅

### ❌ STILL NEEDED
| What | Who | Priority |
|------|-----|----------|
| Real API keys in .env (OpenRouter + Google Vision) | Landon | HIGH |
| Partial ingredient matching in scan.py | Landon | HIGH |
| Expand ingredient list in DB (15+ more items) | Landon | MEDIUM |
| Full QA checklist | Adrian | HIGH |
| BUGS.md | Adrian | HIGH |
| README.md | Adrian | MEDIUM |
| Add 4+ more seeded recipes (Vegetarian, Low-Cal) | Marco | LOW |

---
---

# 👤 MARC — FRONTEND ✅ ALL TASKS COMPLETE

## Your tasks are DONE. Here's what was completed:

1. ✅ Home screen loads real suggested recipes from /api/recipes
2. ✅ Favorites screen loads from /api/favorites (real API)
3. ✅ History screen loads from /api/history (real API, grouped by date)
4. ✅ Heart button loads initial favorite state + persists toggle to backend
5. ✅ "Finish Cooking" logs history to /api/history + increments local recipe count
6. ✅ Profile screen syncs recipe_count from /api/history/stats

## To run the app:
```
cd plately/frontend
flutter pub get
flutter run
```
Backend must be running (`python app.py` in plately/backend).

## What to do now:
- Wait for Landon to add the real API keys
- Test the heart button and "Finish Cooking" flow with backend running
- If something is broken, tell Adrian and add to BUGS.md

---
---

# 👤 MARCO — BACKEND ✅ ALL ROUTES DONE

## What's been completed (by Claude on Marc's machine):
- GET/POST /api/favorites — done ✅ (`routes/favorites.py`)
- GET /api/favorites/check/<id> — done ✅
- DELETE /api/favorites/<id> — done ✅
- GET/POST /api/history — done ✅ (`routes/history.py`)
- GET /api/history/stats — done ✅
- Both blueprints registered in `app.py` ✅

## What you still need to do:

### TASK 1 — Pull and test all routes
```
git checkout dev
git pull
cd plately/backend
pip install -r requirements.txt
python app.py
```

Then test in Postman:
```
GET  http://localhost:5000/api/health
GET  http://localhost:5000/api/favorites?user_id=default         → empty list []
POST http://localhost:5000/api/favorites  body: {"user_id":"default","recipe_id":1}
GET  http://localhost:5000/api/favorites?user_id=default         → should have recipe 1
GET  http://localhost:5000/api/favorites/check/1?user_id=default → {"is_favorite":true}
DELETE http://localhost:5000/api/favorites/1?user_id=default
POST http://localhost:5000/api/history body: {"user_id":"default","action_type":"cooked","ingredient_names":"chicken, eggs","recipe_count":1}
GET  http://localhost:5000/api/history?user_id=default           → should have 1 entry
GET  http://localhost:5000/api/history/stats?user_id=default     → total_sessions, total_recipes, sessions_this_week
```

### TASK 2 — Seed 4 more recipes (covers Vegetarian and Low-Cal tags)
Open `backend/database.py`, inside `_seed()`, add to the `recipes` list:

```python
{
    "name": "Tofu Scramble",
    "cook_time": "12 min",
    "difficulty": "Easy",
    "tags": "Vegetarian,Low-Cal,High-Protein",
    "instructions": "1. Crumble tofu into pan.\n2. Add garlic and onion, sauté 3 min.\n3. Season with soy sauce and pepper.\n4. Add spinach, cook 2 min.\n5. Serve with toast.",
    "nutrition": (280, 22, 18, 10),
    "ingredients": [("tofu", "200g"), ("garlic", "2 cloves"), ("onion", "0.5"), ("soy sauce", "1 tbsp"), ("spinach", "1 cup")],
},
{
    "name": "Greek Salad Bowl",
    "cook_time": "10 min",
    "difficulty": "Easy",
    "tags": "Vegetarian,Low-Cal",
    "instructions": "1. Chop tomatoes, cucumber, onion.\n2. Add olive oil, lemon juice, salt.\n3. Toss gently.\n4. Top with cheese if desired.\n5. Serve immediately.",
    "nutrition": (240, 12, 22, 11),
    "ingredients": [("tomato", "2"), ("cucumber", "1"), ("onion", "0.5"), ("olive oil", "2 tbsp"), ("lemon", "0.5"), ("cheese", "40g")],
},
```

Then delete the old database so it re-seeds:
```
del plately\backend\db\plately.db
python app.py
```
The DB will be recreated with the new recipes.

### TASK 3 — Add ingredients to DB seed
Same file, find the `ingredients` list, add:
```python
"tofu", "spinach", "cucumber", "bell pepper", "potato",
"carrot", "mushroom", "salmon", "bread", "milk", "noodles",
"pork", "cabbage", "flour", "sugar",
```

---
---

# 👤 LANDON — AI & DATA

## What's already done ✅
- POST /api/chat → coded, uses OpenRouter Mistral-7B (mock fallback if no key)
- POST /api/scan → coded, uses Google Vision API (mock fallback if no key)
- AI Chat screen → calls backend, shows real replies
- Ingredient Entry → sends base64 to /api/scan

## What's MISSING ❌
- No real API keys → everything returns mock/fallback
- Scan matching is exact-only (Vision says "chicken meat", DB has "chicken" — no match)

## Your Tasks

### TASK 1 — Get API keys (both FREE)

**OpenRouter (AI Chat):**
1. Go to https://openrouter.ai
2. Sign up → Dashboard → API Keys → Create Key
3. Copy key (starts with `sk-or-...`)

**Google Cloud Vision:**
1. Go to https://console.cloud.google.com
2. Create project "plately" → Enable Cloud Vision API
3. APIs & Services → Credentials → Create API Key

**Put in `backend/.env`:**
```
OPENROUTER_API_KEY=sk-or-your-key-here
GOOGLE_VISION_API_KEY=your-vision-key-here
FLASK_ENV=development
SECRET_KEY=plately-dev-secret
```
⚠️ .env is gitignored — will NOT push. That's correct.

---

### TASK 2 — Fix ingredient matching (partial match)
File: `backend/routes/scan.py`

Replace the matching block with:
```python
known = _known_ingredients()
matched = []
for label in labels:
    for ingredient in known:
        if ingredient in label or label in ingredient:
            if ingredient not in matched:
                matched.append(ingredient)
```

---

### TASK 3 — Expand ingredients in DB
File: `backend/database.py` → inside `_seed()`, find the `ingredients` list, extend it:
```python
"tofu", "spinach", "cucumber", "bell pepper", "potato",
"carrot", "mushroom", "salmon", "bread", "milk", "noodles",
"pork", "cabbage",
```

---

### TASK 4 — Test AI Chat
Postman: `POST http://localhost:5000/api/chat`
Body: `{"message": "what can I cook with chicken and eggs?"}`
Expected: Real Mistral AI reply, not the 1-sentence fallback.

### TASK 5 — Test Image Scan
Postman: `POST http://localhost:5000/api/scan`
Body: `{"image_base64": "<base64 string of food photo>"}`
Get test base64: https://base64.guru/converter/encode/image
Expected: Returns matching ingredients from DB.

---
---

# 👤 ADRIAN — QA & DOCS

## Run everything (both terminals open)
```
Terminal 1:  cd plately/backend && python app.py
Terminal 2:  cd plately/frontend && flutter run
```

## Your Tasks

### TASK 1 — Full test checklist (write PASS/FAIL in docs/BUGS.md)

**SPLASH & AUTH**
```
[ ] Splash 3-page carousel swipes
[ ] Get Started → Login
[ ] Login screen loads
[ ] Sign Up screen loads
[ ] Back navigation works
```

**HOME**
```
[ ] Loads with real recipe cards from backend (not blank)
[ ] Greeting changes by time of day
[ ] "Add Ingredients" card opens IngredientEntryScreen
[ ] Browse → RecipeResultsScreen (all recipes)
[ ] Ask AI → AiChatScreen
[ ] History → HistoryScreen
[ ] Avatar → Profile tab
[ ] Recent Activity shows real entries after cooking
```

**INGREDIENT ENTRY**
```
[ ] Camera mode opens live camera
[ ] Shutter button scans photo → adds detected ingredients
[ ] Torch button toggles flash
[ ] Camera flip works
[ ] Type mode: typing + enter adds chip
[ ] Comma-separated input works
[ ] Remove chip (×) works
[ ] Find Recipes → RecipeResultsScreen
[ ] Empty state error shows if no ingredients added
```

**RECIPE RESULTS**
```
[ ] Recipes load from backend
[ ] Shimmer shows while loading
[ ] Filter chips work (All, Asian, Italian, etc.)
[ ] "X found" count updates with filter
[ ] Tap card → RecipeDetailScreen
[ ] Error state if backend offline
[ ] Retry button works
```

**RECIPE DETAIL**
```
[ ] Recipe name, time, difficulty, calories, protein correct
[ ] Ingredients tab: checklist works, ticking strikes through
[ ] Steps tab: numbered steps correct
[ ] Heart button fills red on tap → state reloads on reopen (persists!)
[ ] AI tip card shows and is relevant
[ ] "Let's Cook" switches to Steps tab
[ ] "Finish Cooking" returns to previous screen
[ ] "Finish Cooking" adds entry to History screen
[ ] Nutrition card shows all 4 macros
```

**FAVORITES**
```
[ ] Loads from backend (initially empty is fine)
[ ] After hearting a recipe in Detail, it appears here on reload
[ ] Search filters by name
[ ] Category filters work
[ ] Empty state shows if no favorites
[ ] Tap recipe card → RecipeDetailScreen
```

**HISTORY**
```
[ ] Loads from backend (initially empty is fine)
[ ] After "Finish Cooking", entry appears here
[ ] Stats card: sessions, total, recipes cooked (not all 0)
[ ] Grouped by Today/Yesterday/This Week/Older
[ ] Tap entry → RecipeResultsScreen
```

**AI CHAT**
```
[ ] Chat loads with greeting bubble
[ ] Quick prompt chips show on first load
[ ] Tap prompt → sends message
[ ] Type + send works
[ ] Typing indicator shows while waiting
[ ] Real AI reply appears (if Landon added keys)
[ ] Mock fallback still shows sensible response (if no keys)
```

**PROFILE**
```
[ ] Name and email load correctly
[ ] Recipe count > 0 after cooking (syncs from backend)
[ ] Edit Profile bottom sheet opens + saves name/email
[ ] Edit Goals bottom sheet opens + saves
[ ] Log Calories opens + saves
[ ] Dietary prefs toggles work
[ ] Help FAQ items expand/collapse
[ ] Sign Out dialog → redirects to Login
```

**NAVIGATION**
```
[ ] Home (nav index 0)
[ ] Saved (nav index 1)
[ ] Scan FAB → IngredientEntryScreen
[ ] AI (nav index 3)
[ ] Profile (nav index 4)
[ ] Back button on all pushed screens
[ ] No navigation crash anywhere
```

---

### TASK 2 — Write docs/BUGS.md
```markdown
# PLATELY V2 — BUG REPORT

## Bug #001
Screen: [name]
What happened: [describe]
Steps to reproduce: [1. 2. 3.]
Severity: Low / Medium / High / Crash
Fixed by: [leave blank]

## Bug #002
...
```

---

### TASK 3 — Update root README.md
```markdown
# Plately V2

A Flutter mobile app that helps students cook affordable, high-protein meals.
Scan or type ingredients, get AI recipe suggestions, track your history.

## Tech Stack
- Frontend: Flutter (Dart) — Android
- Backend: Python Flask + SQLite
- AI: OpenRouter (Mistral-7B)
- Scan: Google Cloud Vision API

## Run

### Backend
cd backend
pip install -r requirements.txt
# Copy .env.example to .env and fill in keys
python app.py

### Frontend
cd frontend
flutter pub get
flutter run

## API Endpoints
GET  /api/health
POST /api/recipes
GET  /api/recipe/<id>
POST /api/scan
POST /api/chat
POST /api/goals
GET/POST /api/favorites
GET/POST /api/history
GET  /api/history/stats

## Team
- Marc — Frontend
- Marco — Backend
- Landon — AI & Data
- Adrian — QA & Docs
```

---

## ⚠️ GOLDEN RULES — EVERYONE

1. ✅ `git pull` before coding — every single time
2. ✅ Paste MEMORY.md + SKILLS.md at start of every Claude session
3. ✅ Add your name/role note at top of Claude paste
4. ✅ Detailed commit messages always
5. ✅ Only work on `dev` branch
6. ✅ Tell next member when you push
7. ❌ Never touch `main` branch
8. ❌ Never commit `.env` file
9. ❌ Never commit with a vague message
10. ❌ Never code without pulling first
