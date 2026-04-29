# 🍽️ PLATELY V2 — TEAM GUIDE
> Read YOUR section only. Follow it step by step.
> Updated after full code assessment.

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

### STEP 4 — Find your local path
```
cd plately
pwd
```
Copy the result. You need it for Claude.

---

## 🧠 EVERY CLAUDE SESSION — ALL MEMBERS

Paste this at the very top of EVERY new Claude chat before anything else:

```
NOTE: I am [Your Name], [Your Role] for Plately V2.
My local project path is: [your path here, e.g. C:\Users\marco\plately]
I am NOT marc. Do not reference marcd paths.

[Paste full MEMORY.md contents here]
[Paste full SKILLS.md contents here]
```

MEMORY.md and SKILLS.md are in the root of the plately folder.

---

## 🔁 RELAY ORDER

```
Marc → push → tell Marco
Marco → push → tell Landon
Landon → push → tell Adrian
Adrian → test → push → done
```

Only ONE person codes at a time.

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
- Bug encountered: describe it
- Fix applied: how you fixed it
- Notes: what next member needs to know"
git push
```

### See what previous member did:
```
git log -1
```

---
---

# 👤 MARC — FRONTEND

## What's already done ✅
- ALL 10 screens exist and are fully designed (UI complete)
- Recipe Results screen → already calls ApiService.getRecipes() ✅
- AI Chat screen → already calls ApiService.sendChat() ✅
- Ingredient Entry screen → camera + type mode, calls ApiService.scanImage() ✅
- Recipe Detail screen → heart/favorite button exists (UI only, not saved to backend yet)
- Home screen → suggested recipes are still HARDCODED (needs API)
- Favorites screen → showing HARDCODED mock data (needs API)
- History screen → showing HARDCODED mock data (needs API)
- Profile screen → stats (recipes cooked, streak, protein avg) are HARDCODED zeros

## Install
- Flutter: https://docs.flutter.dev/get-started/install
- Android Studio: https://developer.android.com/studio

## Run the app
```
cd plately/frontend
flutter pub get
flutter run
```
Emulator or phone must be connected. Backend must also be running.

---

## Your Tasks (in order)

### TASK 1 — Home Screen: load real recipes
File: `frontend/lib/screens/home_screen.dart`

Problem: `_suggested` is a hardcoded list of 4 recipes.
Fix: Replace with real API call on initState.

```dart
// Add to imports
import '../services/api_service.dart';
import '../models/recipe.dart';

// Replace _suggested const with:
List<Recipe> _suggested = [];

// In initState(), after _loadInitials():
_loadSuggested();

// Add this method:
Future<void> _loadSuggested() async {
  final recipes = await ApiService.getRecipes([]);
  if (mounted) setState(() => _suggested = recipes.take(4).toList());
}
```

Then update `_buildSuggestedRecipes()` to use `_suggested` as `List<Recipe>` instead of the const map list. Each card should pass `r.name`, `r.cookTime`, `'${r.calories} cal'`, `'${r.protein}g protein'`, `r.difficulty`.

---

### TASK 2 — Favorites Screen: load from API
File: `frontend/lib/screens/favorites_screen.dart`

Problem: `_favorites` is a hardcoded const list.
Fix: Replace with API call. Wait for Marco to finish the favorites routes first.

```dart
// Replace hardcoded _favorites with:
List<Recipe> _favorites = [];
bool _loading = true;

// In initState():
_loadFavorites();

// Add method:
Future<void> _loadFavorites() async {
  final favs = await ApiService.getFavorites();
  if (mounted) setState(() { _favorites = favs; _loading = false; });
}
```

Add `getFavorites()` to `api_service.dart` once Marco pushes the route.

---

### TASK 3 — History Screen: load from API
File: `frontend/lib/screens/history_screen.dart`

Problem: `_grouped` is hardcoded static data.
Fix: Replace with API call after Marco finishes history routes.

Convert to StatefulWidget, add initState that calls `ApiService.getHistory()`, and render real history grouped by date.

---

### TASK 4 — Profile Screen: real stats
File: `frontend/lib/screens/profile_screen.dart`

Problem: `_recipeCount`, `_streakDays`, `_proteinAvg` are all 0 from UserPrefsService (local only).
Fix: After history API exists, calculate real recipe count from history length.
For now: make sure when a user cooks (hits "Finish Cooking" in RecipeDetailScreen), it increments recipe_count in UserPrefsService.

File: `frontend/lib/screens/recipe_detail_screen.dart`
Find the "Finish Cooking" button tap → add:
```dart
await UserPrefsService.incrementRecipeCount();
```
Add `incrementRecipeCount()` to UserPrefsService.

---

### TASK 5 — Favorites: wire heart button to API
File: `frontend/lib/screens/recipe_detail_screen.dart`

The `_isFavorited` bool is local state only — not saved anywhere.
Fix: On heart tap, call `ApiService.toggleFavorite(recipeId)`.
Add to `api_service.dart`:
```dart
static Future<void> toggleFavorite(int recipeId) async {
  await http.post(
    Uri.parse('$baseUrl/api/favorites'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_id': 'default', 'recipe_id': recipeId}),
  );
}
```

---

## Claude prompt to add each session:
```
NOTE: I am Marc, Frontend Developer for Plately V2.
My local project path is: C:\Users\marcd\plately-v2
I am working on connecting Flutter screens to the Flask backend.
Currently working on: [state which task]
Backend is running at http://10.0.2.2:5000 (Android emulator).
```

---
---

# 👤 MARCO — BACKEND

## What's already done ✅
- Flask app fully set up (app.py, CORS, blueprints)
- GET/POST /api/recipes → works, returns seeded recipes
- GET /api/recipe/<id> → works, returns full detail
- POST /api/chat → works (uses OpenRouter or fallback)
- POST /api/scan → works (uses Vision API or mock fallback)
- POST /api/goals → works (Mifflin-St Jeor TDEE calculator)
- SQLite schema: ingredients, recipes, recipe_ingredients, nutrition, history, favorites
- 6 seeded recipes with nutrition data

## What's MISSING ❌
- NO favorites routes (GET/POST/DELETE)
- NO history routes (GET/POST)
- These tables exist in the DB but have no API endpoints

## Install
- Python 3.10+: https://www.python.org/downloads
- VS Code: https://code.visualstudio.com

## Run the backend
```
cd plately/backend
pip install -r requirements.txt
python app.py
```

## Test with Postman
Download: https://www.postman.com/downloads

Confirm existing routes work first:
```
GET  http://localhost:5000/api/health           → should return {"status":"ok"}
POST http://localhost:5000/api/recipes          → body: {"ingredients":["chicken"]}
GET  http://localhost:5000/api/recipe/1         → returns recipe 1 detail
POST http://localhost:5000/api/goals            → body: {"weight":70,"height":175,"age":20,"sex":"male","goal":"maintain"}
```

---

## Your Tasks (in order)

### TASK 1 — Add Favorites routes
Add to `backend/routes/recipes.py`:

```python
@bp.route('/api/favorites', methods=['POST'])
def add_favorite():
    try:
        data = request.json or {}
        user_id = data.get('user_id', 'default')
        recipe_id = data.get('recipe_id')
        if not recipe_id:
            return jsonify({"status": "error", "message": "recipe_id required"}), 400
        execute(
            "INSERT OR IGNORE INTO favorites (user_id, recipe_id) VALUES (?,?)",
            (user_id, recipe_id)
        )
        return jsonify({"status": "ok", "data": {"saved": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@bp.route('/api/favorites', methods=['GET'])
def get_favorites():
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query("""
            SELECT r.*, n.calories, n.protein, n.carbs, n.fat
            FROM favorites f
            JOIN recipes r ON r.id = f.recipe_id
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            WHERE f.user_id = ?
            ORDER BY f.id DESC
        """, (user_id,))
        return jsonify({"status": "ok", "data": rows}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@bp.route('/api/favorites/<int:recipe_id>', methods=['DELETE'])
def remove_favorite(recipe_id):
    try:
        user_id = request.args.get('user_id', 'default')
        execute(
            "DELETE FROM favorites WHERE user_id = ? AND recipe_id = ?",
            (user_id, recipe_id)
        )
        return jsonify({"status": "ok", "data": {"removed": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
```

### TASK 2 — Add History routes
Create new file `backend/routes/history.py`:

```python
from flask import Blueprint, request, jsonify
from database import query, execute

bp = Blueprint('history', __name__)

@bp.route('/api/history', methods=['POST'])
def add_history():
    try:
        data = request.json or {}
        user_id = data.get('user_id', 'default')
        action_type = data.get('action_type', 'cooked')
        ingredient_names = data.get('ingredient_names', '')
        recipe_count = data.get('recipe_count', 1)
        execute(
            "INSERT INTO history (user_id, action_type, ingredient_names, recipe_count) VALUES (?,?,?,?)",
            (user_id, action_type, ingredient_names, recipe_count)
        )
        return jsonify({"status": "ok", "data": {"logged": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@bp.route('/api/history', methods=['GET'])
def get_history():
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query("""
            SELECT * FROM history
            WHERE user_id = ?
            ORDER BY timestamp DESC
            LIMIT 50
        """, (user_id,))
        return jsonify({"status": "ok", "data": rows}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
```

### TASK 3 — Register history blueprint in app.py
Open `backend/app.py`, add after the other imports:
```python
from routes.history import bp as history_bp
```
And after the other register_blueprint lines:
```python
app.register_blueprint(history_bp)
```

### TASK 4 — Seed more recipes (optional but helpful)
Open `backend/database.py`, add 3-4 more recipes to the `recipes` list inside `_seed()`.
Make sure to cover tags: Vegetarian, Low-Cal.
Use same format as existing entries.

---

## Claude prompt each session:
```
NOTE: I am Marco, Backend Developer for Plately V2.
My local project path is: C:\Users\[yourname]\plately
I am building Flask routes and SQLite for Plately V2.
Currently working on: [favorites / history / seeding]
The database schema is already set up. Routes go in backend/routes/.
```

---
---

# 👤 LANDON — AI & DATA

## What's already done ✅
- POST /api/chat → fully coded, uses OpenRouter Mistral-7B (falls back to mock if no key)
- POST /api/scan → fully coded, uses Google Vision API (falls back to mock ingredients if no key)
- AI Chat screen in Flutter → already calls the backend, shows real replies
- Ingredient Entry screen → already sends base64 to /api/scan
- The code works — it just needs REAL API keys to do real things

## What's MISSING ❌
- No actual API keys in .env → everything returns mock/fallback data
- Scan ingredient matching is too strict (exact match only, Vision returns broad labels)
- No partial matching (Vision says "chicken meat" but DB only has "chicken")

## Install
- Python 3.10+: https://www.python.org/downloads
- VS Code: https://code.visualstudio.com

## Run the backend
```
cd plately/backend
pip install -r requirements.txt
python app.py
```

---

## Your Tasks (in order)

### TASK 1 — Get API keys (both FREE)

**OpenRouter (AI Chat):**
1. Go to https://openrouter.ai
2. Sign up with Google
3. Dashboard → API Keys → Create Key
4. Copy the key (starts with sk-or-...)

**Google Cloud Vision (Image Scan):**
1. Go to https://console.cloud.google.com
2. Create new project → name it "plately"
3. Search bar → "Cloud Vision API" → Enable
4. Left menu → APIs & Services → Credentials → Create Credentials → API Key
5. Copy the key

**Put both keys in `backend/.env`:**
```
OPENROUTER_API_KEY=sk-or-your-key-here
GOOGLE_VISION_API_KEY=your-vision-key-here
FLASK_ENV=development
SECRET_KEY=plately-dev-secret
```
⚠️ .env is in .gitignore — it will NOT be pushed to GitHub. That's correct.

---

### TASK 2 — Test AI Chat is working
Run the backend, then in Postman:
```
POST http://localhost:5000/api/chat
Body (raw JSON): {"message": "what can I cook with chicken and eggs?"}
```
Expected: A real reply from Mistral AI, not the fallback mock sentence.
If you still get the fallback → check that .env is in the backend/ folder and python-dotenv is installed.

---

### TASK 3 — Test Image Scan is working
```
POST http://localhost:5000/api/scan
Body: {"image_base64": "..."}
```
To get a test base64 image, go to https://base64.guru/converter/encode/image and upload any food photo. Copy the base64 string and paste it in Postman.

Expected: Returns list of detected ingredients that match the DB.

---

### TASK 4 — Fix ingredient matching (partial match)
File: `backend/routes/scan.py`

Current problem: Vision returns labels like "chicken meat", "leafy vegetable", "cooked rice" but the DB only has "chicken", "rice", "mixed vegetables". Exact match fails.

Fix: Add fuzzy/partial matching:

```python
# Replace the matching logic in scan() with this:
known = _known_ingredients()
matched = []
for label in labels:
    for ingredient in known:
        if ingredient in label or label in ingredient:
            if ingredient not in matched:
                matched.append(ingredient)
```

---

### TASK 5 — Expand ingredients in DB
File: `backend/database.py` inside `_seed()`, find the `ingredients` list and add:
```python
"potato", "carrot", "mushroom", "spinach", "salmon",
"tofu", "bread", "milk", "flour", "sugar", "noodles",
"pork", "cabbage", "cucumber", "bell pepper",
```

---

## Claude prompt each session:
```
NOTE: I am Landon, AI & Data Developer for Plately V2.
My local project path is: C:\Users\[yourname]\plately
I am working on OpenRouter AI chat and Google Vision scan integration.
The routes already exist in backend/routes/chat.py and backend/routes/scan.py.
I need to add API keys and improve ingredient matching.
Currently working on: [keys / chat test / scan test / matching fix]
```

---
---

# 👤 ADRIAN — QA & DOCS

## What you need installed
- Flutter: https://docs.flutter.dev/get-started/install
- Python 3.10+: https://www.python.org/downloads
- Android Studio or VS Code

## Run everything (BOTH terminals must be open)
```
Terminal 1:  cd plately/backend && python app.py
Terminal 2:  cd plately/frontend && flutter run
```

---

## Your Tasks (in order)

### TASK 1 — Full app test checklist
Go through every screen. For each item write PASS or FAIL in `docs/BUGS.md`.

**SPLASH & AUTH**
```
[ ] Splash screen loads without crashing
[ ] 3-page carousel swipes correctly
[ ] "Get Started" button goes to Login
[ ] Login screen opens
[ ] Sign Up screen opens
[ ] Back navigation works from Login/SignUp
```

**MAIN APP**
```
[ ] Home screen loads with recipe cards (not blank)
[ ] Greeting text changes based on time of day
[ ] "Add Ingredients" card opens Ingredient Entry screen
[ ] Browse button opens Recipe Results (all recipes)
[ ] Ask AI button opens AI Chat
[ ] History button opens History screen
[ ] Profile avatar opens Profile tab
```

**INGREDIENT ENTRY**
```
[ ] Camera mode shows live camera view
[ ] Shutter button takes a photo and scans
[ ] Torch button toggles flash
[ ] Camera flip button works
[ ] Type mode shows text input
[ ] Typing an ingredient and pressing arrow adds it as a chip
[ ] Comma-separated entry works (chicken, rice → 2 chips)
[ ] Removing a chip (× button) works
[ ] "Find Recipes" button goes to results
[ ] "Add ingredients first" error shows if none added
```

**RECIPE RESULTS**
```
[ ] Recipes load from backend (not blank)
[ ] Loading shimmer shows while fetching
[ ] Filter buttons (All, Asian, Italian, etc.) work
[ ] "X found" count updates when filter changes
[ ] Tapping a recipe card opens Recipe Detail
[ ] Error state shows if backend is offline
[ ] Retry button works after error
```

**RECIPE DETAIL**
```
[ ] Recipe name, cook time, difficulty show correctly
[ ] Calories and protein badge show
[ ] Ingredients tab shows ingredient list with amounts
[ ] Checking off an ingredient strikes it through
[ ] Steps tab shows numbered steps
[ ] Heart/favorite button fills red when tapped, unfills when tapped again (no diagonal line)
[ ] AI Tip card shows at bottom
[ ] "Let's Cook" button switches to Steps tab
[ ] "Finish Cooking" button pops back
[ ] Nutrition card shows all 4 macros
```

**FAVORITES**
```
[ ] Favorites screen loads
[ ] Search bar filters recipes by name
[ ] Category filter buttons work
[ ] Empty state shows if no favorites
[ ] Tapping a recipe card navigates correctly
```

**HISTORY**
```
[ ] History screen loads
[ ] Stats card shows (sessions, total, recipes cooked)
[ ] Grouped entries show (Today / Yesterday / This Week / Older)
[ ] Tapping an entry opens Recipe Results
```

**AI CHAT**
```
[ ] Chat screen loads with greeting message
[ ] Quick prompt chips show on first load
[ ] Tapping a quick prompt sends it
[ ] Typing a message and sending works
[ ] Typing indicator (3 dots) shows while waiting
[ ] AI reply appears correctly
[ ] User bubble appears on right, AI bubble on left
```

**PROFILE**
```
[ ] Profile screen loads without error
[ ] Name and email show
[ ] Stats row (recipes, streak, protein) shows
[ ] Progress bars for calories and protein show
[ ] Edit Profile bottom sheet opens
[ ] Edit Goals bottom sheet opens
[ ] Log Calories sheet opens
[ ] Dietary preference toggles work
[ ] Sign out dialog appears and works
[ ] Help & Support FAQ items expand/collapse
```

**NAVIGATION**
```
[ ] Bottom nav: Home (index 0) works
[ ] Bottom nav: Favorites (index 1) works
[ ] Bottom nav: Scan FAB (center) opens Ingredient Entry
[ ] Bottom nav: AI Chat (index 3) works
[ ] Bottom nav: Profile (index 4) works
[ ] Back button works on all pushed screens
```

---

### TASK 2 — Write BUGS.md
Create file `docs/BUGS.md`:
```
# PLATELY V2 — BUG REPORT

## Bug #1
Screen: [name]
What happened: [describe]
Steps to reproduce: [how to trigger]
Severity: Low / Medium / High / Crash
Fixed by: [leave blank if not fixed]

## Bug #2
...
```

---

### TASK 3 — Write README.md
Update the root `README.md`:

```markdown
# Plately V2

A Flutter mobile app that helps students cook affordable, high-protein meals.
Scan or type ingredients, get AI recipe suggestions, track your cooking history.

## Tech Stack
- Frontend: Flutter (Dart) — Android
- Backend: Python Flask + SQLite
- AI Chat: OpenRouter (Mistral-7B)
- Image Scan: Google Cloud Vision API
- Auth: Firebase (planned)

## How to Run

### Backend
cd backend
pip install -r requirements.txt
python app.py

### Frontend
cd frontend
flutter pub get
flutter run

## Team
- Marc — Frontend (Flutter screens, UI)
- Marco — Backend (Flask routes, SQLite)
- Landon — AI & Data (OpenRouter, Vision API)
- Adrian — QA & Documentation

## Known Issues
[List from BUGS.md]
```

---

### TASK 4 — Check all commits
```
git log --oneline
```
Every commit should follow the format. Note any vague commits in BUGS.md under "Process Issues".

---

## Claude prompt each session:
```
NOTE: I am Adrian, QA & Documentation for Plately V2.
My local project path is: C:\Users\[yourname]\plately
I am testing the full app and writing documentation.
Currently working on: [testing / BUGS.md / README]
```

---
---

## ⚠️ GOLDEN RULES — EVERYONE

1. ✅ `git pull` before coding — every single time
2. ✅ Paste MEMORY.md + SKILLS.md at the start of every Claude session
3. ✅ Add your name/role note at top of Claude paste
4. ✅ Detailed commit messages always
5. ✅ Only work on `dev` branch
6. ✅ Tell next member when you push
7. ❌ Never touch `main` branch
8. ❌ Never commit `.env` file
9. ❌ Never commit with a vague message
10. ❌ Never code without pulling first
