# 🍽️ PLATELY V2 — TEAM GUIDE
> This file tells each member exactly what to do, how to set up, and how to work.
> Read YOUR section only. Follow it step by step.

---

## 👥 TEAM ROLES

| Name   | Role         | Responsibility                          |
|--------|-------------|------------------------------------------|
| Marc   | Frontend     | Flutter screens, UI, API connection      |
| Marco  | Backend      | Flask routes, SQLite, favorites, history |
| Landon | AI & Data    | OpenRouter chat, Google Vision scan      |
| Adrian | QA & Docs    | Testing every screen, README, bug report |

---

## ⚙️ ONE-TIME SETUP (ALL MEMBERS)

### STEP 1 — Install Git
Download: https://git-scm.com/downloads
Install with default settings.

### STEP 2 — Clone the repo
Open PowerShell or any terminal and run:
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
Run this in terminal:
```
cd plately
pwd
```
Copy the result — you'll need it for Claude.

---

## 🧠 EVERY CLAUDE SESSION (ALL MEMBERS)

Every time you open a new Claude chat, paste this at the very top BEFORE anything else:

```
NOTE: I am [Your Name], [Your Role].
My local project path is: [paste your path here, e.g. C:\Users\marco\plately]
I am NOT marc. Do not reference marc's paths or marcd username.

[Then paste the full contents of MEMORY.md]
[Then paste the full contents of SKILLS.md]
```

Both MEMORY.md and SKILLS.md are in the root of the plately folder.
Without these, Claude has zero knowledge of the project.

---

## 🔁 RELAY ORDER & RULES

```
Marc → push → tell Marco
Marco → push → tell Landon
Landon → push → tell Adrian
Adrian → test everything → push
```

Only ONE person codes at a time.
Wait for the previous member to confirm they pushed before you start.

### Before EVERY coding session:
```
git checkout dev
git pull
```
NEVER skip this.

### After EVERY coding session:
```
git add .
git commit -m "your detailed message"
git push
```
Then tell the next member.

### Commit message format (REQUIRED):
```
[yourname] - [what you did]

- Built: what you added
- Changed: what you modified
- Bug encountered: describe it
- Fix applied: how you fixed it
- Notes: what the next member needs to know
```

### To see what the previous member did:
```
git log -1
```

---

---

# 👤 MARC — FRONTEND

## Install
- Flutter SDK: https://docs.flutter.dev/get-started/install
- Android Studio: https://developer.android.com/studio
- VS Code (optional): https://code.visualstudio.com

## Run the app
```
cd plately/frontend
flutter pub get
flutter run
```
Make sure an emulator is running or a phone is connected.

## Your Tasks

### Task 1 — Connect Home Screen to real API
File: `frontend/lib/screens/home_screen.dart`
- The suggested recipes list `_suggested` is hardcoded
- Replace it by calling `ApiService.getRecipes([])` in `initState()`
- Show a loading spinner while fetching
- Display real recipes from backend

### Task 2 — Connect Recipe Results Screen
File: `frontend/lib/screens/recipe_results_screen.dart`
- When ingredients are passed in, call `ApiService.getRecipes(ingredients)`
- Show loading spinner while waiting
- Show "No recipes found" if empty list returned

### Task 3 — Connect Recipe Detail Screen
File: `frontend/lib/screens/recipe_detail_screen.dart`
- Call `ApiService.getRecipeDetail(id)` to load real steps, ingredients, macros
- Replace any hardcoded nutrition numbers with real data from API

### Task 4 — Wire up Favorites
File: `frontend/lib/screens/favorites_screen.dart`
- Connect the heart button to save/remove from backend
- Call favorites API endpoints when Marco finishes them

## Claude prompt to add each session:
```
NOTE: I am Marc, Frontend Developer.
My local project path is: C:\Users\marcd\plately-v2
I am working on connecting Flutter screens to the Flask API.
Currently working on: [name the screen]
```

---

---

# 👤 MARCO — BACKEND

## Install
- Python 3.10+: https://www.python.org/downloads
- VS Code: https://code.visualstudio.com

## Run the backend
```
cd plately/backend
pip install -r requirements.txt
python app.py
```
Leave this terminal open. Flask must stay running.

## Test routes with Postman
Download Postman: https://www.postman.com/downloads

Test these one by one to confirm they work:
```
POST http://localhost:5000/api/recipes
Body: {"ingredients": ["chicken", "eggs"]}

GET  http://localhost:5000/api/recipe/1

POST http://localhost:5000/api/goals
Body: {"weight":70,"height":175,"age":20,"sex":"male","goal":"maintain","activity":"moderate"}

GET  http://localhost:5000/api/health
```

## Your Tasks

### Task 1 — Add Favorites routes (MISSING — build this)
Create or add to `backend/routes/recipes.py`:
- `POST /api/favorites` — body: `{user_id, recipe_id}` — saves a favorite
- `GET /api/favorites?user_id=default` — returns list of saved recipes
- `DELETE /api/favorites/<recipe_id>` — removes a favorite

### Task 2 — Add History routes (MISSING — build this)
Create `backend/routes/history.py`:
- `POST /api/history` — body: `{user_id, action_type, ingredient_names, recipe_count}` — logs a session
- `GET /api/history?user_id=default` — returns history list grouped by date

### Task 3 — Register new routes in app.py
After creating the new route files, add them to `backend/app.py`:
```python
from routes.history import bp as history_bp
app.register_blueprint(history_bp)
```

### Task 4 — Seed more recipes (optional)
Add 4+ more recipes to the `_seed()` function in `database.py`
Make sure they cover: Vegetarian, Low-Cal, Asian, Italian tags

## Claude prompt to add each session:
```
NOTE: I am Marco, Backend Developer.
My local project path is: C:\Users\[yourname]\plately
I am working on Flask routes and SQLite for Plately V2.
Currently working on: [favorites / history / seeding]
```

---

---

# 👤 LANDON — AI & DATA

## Install
- Python 3.10+: https://www.python.org/downloads
- VS Code: https://code.visualstudio.com

## Run the backend
```
cd plately/backend
pip install -r requirements.txt
python app.py
```

## Your Tasks

### Task 1 — Get API keys (FREE)

**OpenRouter (AI Chat):**
1. Go to https://openrouter.ai
2. Sign up with Google
3. Go to API Keys → Create key
4. Copy the key

**Google Vision (Image Scan):**
1. Go to https://console.cloud.google.com
2. Create a new project called "plately"
3. Search "Cloud Vision API" → Enable it
4. Go to Credentials → Create API Key
5. Copy the key

**Put both keys in `backend/.env`:**
```
OPENROUTER_API_KEY=paste_your_key_here
GOOGLE_VISION_API_KEY=paste_your_key_here
```
⚠️ Never commit .env to GitHub. It's already in .gitignore.

### Task 2 — Test AI Chat
Run the backend, then in Postman:
```
POST http://localhost:5000/api/chat
Body: {"message": "what can I cook with chicken and eggs?"}
```
Should return a real AI reply from Mistral, not the fallback mock text.
If it returns the fallback, the key is wrong or not loaded.

### Task 3 — Test Image Scan
```
POST http://localhost:5000/api/scan
Body: {"image_base64": "...base64 string..."}
```
Should return matched ingredients from the database.
File: `backend/routes/scan.py` — the logic is already written, just needs the key.

### Task 4 — Improve ingredient matching
File: `backend/routes/scan.py`
- Vision API returns broad labels like "food", "dish", "cuisine"
- Improve the filter to also do partial matching, not just exact match
- Example: Vision returns "chicken meat" → match to "chicken" in DB

### Task 5 — Expand ingredients list in DB
File: `backend/database.py` inside `_seed()`
- Add more ingredients to the seed list so scan matches more items
- Add: potato, carrot, mushroom, spinach, salmon, tofu, bread, milk, flour, sugar

## Claude prompt to add each session:
```
NOTE: I am Landon, AI & Data Developer.
My local project path is: C:\Users\[yourname]\plately
I am working on OpenRouter AI chat and Google Vision scan integration.
Currently working on: [chat / scan / ingredient matching]
```

---

---

# 👤 ADRIAN — QA & DOCS

## Install
- Flutter SDK: https://docs.flutter.dev/get-started/install
- Android Studio or VS Code
- Python 3.10+

## Run everything (you need BOTH running)
```
Terminal 1:  cd plately/backend && python app.py
Terminal 2:  cd plately/frontend && flutter run
```

## Your Tasks

### Task 1 — Full app test checklist
Go through every screen and check each box. Write results in `docs/BUGS.md`:

```
[ ] Splash screen loads and carousels through 3 pages
[ ] Login screen opens without crashing
[ ] Sign up screen opens without crashing
[ ] Home screen loads with recipes (not blank/loading forever)
[ ] Tap "Add Ingredients" → ingredient entry screen opens
[ ] Type an ingredient → recipe results appear
[ ] Tap a recipe → detail screen opens with correct info
[ ] Ingredients tab shows ingredient list
[ ] Steps tab shows numbered steps
[ ] Heart/favorite button toggles correctly (filled = saved, empty = not saved)
[ ] Favorites screen loads
[ ] History screen loads
[ ] AI Chat → type a message → get a real reply (not mock)
[ ] Profile screen loads without error
[ ] Bottom nav switches between all 5 tabs
[ ] Scan button on bottom nav opens ingredient entry
[ ] App does not crash when backend is offline
```

### Task 2 — Write BUGS.md
Create `docs/BUGS.md` and log every bug you find:
```
## Bug #1
Screen: [screen name]
What happened: [describe]
Steps to reproduce: [how to trigger it]
Severity: Low / Medium / High / Crash
Fixed by: [leave blank if not fixed]
```

### Task 3 — Write final README.md
Update the README.md in the project root with:
- What Plately does (2-3 sentences)
- Tech stack (Flutter + Flask + SQLite + OpenRouter + Google Vision)
- How to run frontend
- How to run backend
- Team members and their roles
- Known issues (from BUGS.md)

### Task 4 — Check commit history
Run this to review what each member did:
```
git log --oneline
```
Make sure everyone followed the commit message format.
If a commit message is too vague, note it in BUGS.md under "Process Issues".

## Claude prompt to add each session:
```
NOTE: I am Adrian, QA & Documentation.
My local project path is: C:\Users\[yourname]\plately
I am testing the full Plately V2 app and writing documentation.
Currently working on: [testing / bugs / README]
```

---

## ⚠️ GOLDEN RULES — EVERYONE

1. ✅ `git pull` before you start coding — every single time
2. ✅ Paste MEMORY.md + SKILLS.md at the start of every Claude session
3. ✅ Add your name/role note at the top of your Claude paste
4. ✅ Write detailed commit messages — always
5. ✅ Only work on `dev` branch
6. ✅ Tell the next member when you push
7. ❌ Never touch `main` branch
8. ❌ Never commit `.env` file
9. ❌ Never commit with a vague message like "done" or "update"
10. ❌ Never code without pulling first
