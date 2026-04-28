# PLATELY V2 — [SKILLS.md](http://SKILLS.md) (GOD TIER)

> Paste alongside [MEMORY.md](http://MEMORY.md) at the start of every chat.

---

## ⚡ TOKEN BUDGET RULES (CRITICAL — READ FIRST)

Claude has a finite context window. Every wasted token = less code we get.

RuleDetail**Complete files only**No `// ...rest stays the same`. Always full file.**One-line summary**Before any code block: one sentence max.\*\*No re-explaining [MEMORY.md](http://MEMORY.md**)Stack, design, screens are documented. Skip.**No multi-message Q&A**Ask all questions at once in one block.**Batch writes**Write multiple related files in sequence, no chatter between.**Reference don't repeat**Say "see AppTheme.primaryDark" not the hex value.**Max response format**Summary line → code → 3 bullets → "Next:"**Skip boilerplate comments**No `// Flutter SDK`, `// material.dart` type comments.**Short var names in local scope**`res`, `ctx`, `fn` etc. fine inside functions.**Compress mock data**3 items in a list = fine for demo. Not 10.

---

## 🧠 ROLE

Senior Flutter/Python engineer. Goal: working demo in 1-2 weeks. Priority order: **runs** &gt; **looks right** &gt; **clean code** &gt; **perfect architecture**

---

## 🎨 FLUTTER FRONTEND RULES

### Architecture

- Material 3 only (`useMaterial3: true`)
- `StatefulWidget` if screen has state, `StatelessWidget` for pure display
- Extract any UI repeated 3+ times → shared widget in `/widgets/`
- Navigation: `Navigator.push` / `Navigator.pushReplacement` / `Navigator.pushAndRemoveUntil`
- `PageController` for splash carousel only

### Styling — NEVER hardcode hex in screens

```dart
// WRONG
color: Color(0xFF043B3C)
// RIGHT
color: AppTheme.primaryDark
```

### Layout rules

- Prefer `Column` / `Row` / `Padding` over `Positioned`
- `Expanded` + `Flexible` for responsive widths
- `SafeArea` wraps every screen body
- `SingleChildScrollView` + `padding: EdgeInsets.only(bottom: 100)` for long screens with bottom nav

### Bottom nav pattern

```dart
bottomNavigationBar: PlatelyBottomNav(currentIndex: N, onTap: _onNavTap),
```

Indices: 0=Home, 1=Favorites, 2=Scan(FAB), 3=AiChat, 4=Profile

### Text fields

- Always `border: InputBorder.none` inside custom Container
- `contentPadding` to control vertical centering
- `obscureText: true` for passwords

### Performance

- `const` on every widget that doesn't change
- `shrinkWrap: true` + `NeverScrollableScrollPhysics` for nested ListViews
- Never put `ListView` inside `SingleChildScrollView` without physics override
- `ListView.builder` for lists &gt; 5 items (lazy rendering)
- `ClipRRect` for image corners — never nest multiple decorations

### Fonts

- `Nunito` → logo and brand headings only
- `DM Sans` → all body, label, button text
- Declare in `pubspec.yaml` under `fonts:`, files go in `assets/fonts/`

---

## 🐍 BACKEND (Flask) RULES

### File structure

```
routes/scan.py      → POST /api/scan
routes/recipes.py   → GET+POST /api/recipes, GET /api/recipe/<id>
routes/chat.py      → POST /api/chat
routes/goals.py     → POST /api/goals
database.py         → all SQLite logic
app.py              → Flask init, register blueprints, CORS
```

### Response contract (always)

```python
# Success
return jsonify({"status": "ok", "data": result}), 200
# Error
return jsonify({"status": "error", "message": str(e)}), 500
```

### Every route needs

```python
from flask import Blueprint, request, jsonify
bp = Blueprint('name', __name__)

@bp.route('/api/path', methods=['POST'])
def handler():
    try:
        # logic
        return jsonify({"status": "ok", "data": result}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
```

### Database patterns

```python
# database.py pattern
import sqlite3, os

DB_PATH = os.path.join(os.path.dirname(__file__), 'db/plately.db')

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # enables dict-like access
    return conn

def query(sql, params=()):
    conn = get_db()
    cur = conn.execute(sql, params)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows

def execute(sql, params=()):
    conn = get_db()
    conn.execute(sql, params)
    conn.commit()
    conn.close()
```

### AI integration — OpenRouter

```python
import requests, os
OPENROUTER_KEY = os.getenv('OPENROUTER_API_KEY')
SYSTEM_PROMPT = "You are Plately, a helpful cooking assistant for students. Be concise."

def ask_ai(user_message):
    res = requests.post(
        'https://openrouter.ai/api/v1/chat/completions',
        headers={'Authorization': f'Bearer {OPENROUTER_KEY}', 'Content-Type': 'application/json'},
        json={'model': 'mistralai/mistral-7b-instruct:free', 'messages': [
            {'role': 'system', 'content': SYSTEM_PROMPT},
            {'role': 'user', 'content': user_message},
        ], 'max_tokens': 300},
        timeout=15,
    )
    return res.json()['choices'][0]['message']['content']
```

### Vision API — Google Cloud

```python
def scan_image(base64_data):
    res = requests.post(
        f'https://vision.googleapis.com/v1/images:annotate?key={VISION_KEY}',
        json={'requests': [{'image': {'content': base64_data}, 'features': [{'type': 'LABEL_DETECTION', 'maxResults': 20}]}]},
        timeout=10,
    )
    labels = [a['description'].lower() for a in res.json()['responses'][0].get('labelAnnotations', [])]
    # Filter to known ingredients only
    known = query("SELECT name FROM ingredients")
    known_names = {r['name'].lower() for r in known}
    return [l for l in labels if l in known_names]
```

### CORS (required for emulator)

```python
from flask_cors import CORS
CORS(app, resources={r"/api/*": {"origins": "*"}})
```

---

## 🔒 SECURITY RULES

AreaRuleAPI KeysAlways `.env` via `python-dotenv`. Never in code.SQLAlways parameterized queries `?` — NEVER f-strings in SQL.Input validationCheck required fields exist before processing. Return 400 if missing.FirebaseOnly use Firebase for Auth (Google + Email). Data stays in SQLite.ImagesValidate base64 format before passing to Vision API.Secrets`.env` in `.gitignore`. Push `.env.example` with blank values.CORSRestrict to `*` only for dev. In prod: restrict to app domain.

```python
# Input validation pattern
data = request.json or {}
if not data.get('ingredients'):
    return jsonify({"status": "error", "message": "ingredients required"}), 400
```

---

## 🚀 PERFORMANCE RULES

### Flutter

- Use `const` constructors everywhere possible
- `ListView.builder` not `ListView(children: [...])` for dynamic lists
- `CachedNetworkImage` for any remote images
- `dispose()` every controller: `TextEditingController`, `ScrollController`, `PageController`
- `WidgetsBinding.instance.addPostFrameCallback` for post-build scroll

### Backend

- Seed DB once on startup with `IF NOT EXISTS` check
- Cache OpenRouter responses for identical messages (dict in memory, MVP only)
- Vision API timeout: 10s. OpenRouter timeout: 15s. Always set timeouts.
- Index DB columns used in WHERE: `recipe_id`, `user_id`, `ingredient_id`

```sql
CREATE INDEX IF NOT EXISTS idx_history_user ON history(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);
```

---

## 🎯 DESIGN TOKENS (quick ref — don't restate in code)

```
primaryDark  = 0xFF043B3C    creamBg    = 0xFFF0EEE9
darkText     = 0xFF083F3F    mutedText  = 0xFF7A7A7A
green        = 0xFF76CC4F    greenDark  = 0xFF3D7B20
purple       = 0xFFBA5CCC    yellow     = 0xFFEABA1C
borderGray   = 0xFFDADADA    lightGray  = 0xFFD9D9D9
scanGreen    = 0xFFC0DCB3    typeBlue   = 0xFFBEC2DC
browseYellow = 0xFFDFDC9E    askPurple  = 0xFFD3A7DC
orange       = 0xFFCCA04F    red        = 0xFFD14444
```

Gradients: `AppTheme.splashGradient` | `AppTheme.tealGradient`Text styles: `AppTheme.logoStyle` | `headingLarge` | `headingMedium` | `bodyMedium` | `bodySmall` | `caption`

---

## 📐 SCREEN STATUS CHECKLIST

ScreenFileStatusSplash (3-page carousel)splash_screen.dart✅ DoneLoginlogin_screen.dart✅ DoneSign Upsignup_screen.dart✅ DoneDashboard/Homehome_screen.dart✅ DoneRecipe Results (grid + filters)recipe_results_screen.dart✅ DoneRecipe Detail (ingredients + steps tabs)recipe_detail_screen.dart✅ DoneFavoritesfavorites_screen.dart✅ DoneHistory / Activityhistory_screen.dart✅ DoneAI Chatai_chat_screen.dart✅ DoneProfileprofile_screen.dart✅ Done

---

## 📋 RESPONSE FORMAT (enforce always)

```
[One line: what this builds]

\`\`\`dart
// complete, copy-paste ready file
\`\`\`

- Does X
- Does Y  
- Does Z

Next: [one specific next step]
```

### NEVER DO

- `// ...` or `// rest stays the same`
- Re-explain the stack or design system
- Ask questions in separate messages
- Use deprecated: `WillPopScope`, `startActivityForResult`, `withOpacity` on const colors
- Hardcode hex values in screens
- Suggest paid APIs
- Create partial implementations

---

## 🛠️ FLUTTER SETUP COMMANDS (one-time)

```powershell
# In plately-v2/frontend/
flutter create . --org com.plately --project-name plately_v2

# Get dependencies
flutter pub get

# Run on emulator
flutter run

# Check for errors
flutter analyze
```

---

## 📦 ENV FILE TEMPLATE

```env
# plately-v2/backend/.env
OPENROUTER_API_KEY=your_key_here
GOOGLE_VISION_API_KEY=your_key_here
FLASK_ENV=development
SECRET_KEY=change-this-in-production
```
