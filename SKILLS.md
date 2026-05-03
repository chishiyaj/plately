# PLATELY V2 — SKILLS.md (GOD TIER)
> Paste alongside MEMORY.md + TASKS.md at the start of every chat.

---

## ⚡ TOKEN BUDGET RULES (CRITICAL)
| Rule | Detail |
|------|--------|
| Complete files only | No `// ...rest stays the same`. Always full file. |
| One-line summary | Before any code block: one sentence max. |
| No re-explaining MEMORY.md | Stack, design, screens are documented. Skip. |
| No multi-message Q&A | Ask all questions at once in one block. |
| Batch writes | Write multiple related files in sequence, no chatter between. |
| Reference don't repeat | Say "see AppTheme.primaryDark" not the hex value. |
| Max response format | Summary line → code → 3 bullets → "Next:" |
| Skip boilerplate comments | No `// Flutter SDK`, `// material.dart` type comments. |

---

## 🧠 ROLE
Senior Flutter/Python engineer. Goal: working demo. Priority: **runs** > **looks right** > **clean code** > **perfect architecture**

---

## 🎨 FLUTTER RULES

### Architecture
- Material 3 only (`useMaterial3: true`)
- `StatefulWidget` if screen has state, `StatelessWidget` for pure display
- Navigation: `Navigator.push` / `Navigator.pushReplacement` / `Navigator.pushAndRemoveUntil`

### Styling — NEVER hardcode hex in screens
```dart
// WRONG
color: Color(0xFF043B3C)
// RIGHT
color: AppTheme.primaryDark
```

### Layout rules
- `SafeArea` wraps every screen body
- `SingleChildScrollView` + `padding: EdgeInsets.only(bottom: 100)` for long screens with bottom nav
- `const` on every widget that doesn't change
- `ListView.builder` for lists > 5 items

### Bottom nav pattern
```dart
bottomNavigationBar: PlatelyBottomNav(currentIndex: N, onTap: _onNavTap),
```
Indices: 0=Home, 1=Favorites, 2=Scan(FAB), 3=AiChat, 4=Profile

### Fonts
- `Nunito` → logo and brand headings only
- `DM Sans` → all body, label, button text

### Packages in use (pubspec.yaml — verified)
- `flutter_animate` — chainable animations
- `lucide_icons_flutter` — icons (not Material icons)
- `shimmer` — skeleton loading
- `glassmorphism` — frosted glass
- `camera` — live camera viewfinder
- `animations` — SharedAxisTransition
- `flutter_svg` — Google G logo
- `firebase_core`, `firebase_auth`, `google_sign_in` — auth
- `flutter_local_notifications`, `timezone` — notifications (wiring pending)
- `cached_network_image` — remote images
- `image_picker`, `shared_preferences`, `sqflite`, `http`

### NEVER USE
- `withOpacity` on const colors → use `withValues(alpha: x)`
- `WillPopScope` → deprecated
- Hardcoded hex in screens
- Paid APIs

---

## 🐍 BACKEND RULES

### File structure (ACTUAL)
```
routes/scan.py      → POST /api/scan (Gemma vision)
routes/recipes.py   → GET+POST /api/recipes, GET /api/recipe/<id>
routes/chat.py      → POST /api/chat (Gemma 3 chat)
routes/goals.py     → POST /api/goals (Mifflin-St Jeor)
routes/favorites.py → GET/POST/DELETE /api/favorites
routes/history.py   → GET/POST/DELETE /api/history
database.py         → Thread-safe SQLite, WAL mode
app.py              → Flask factory, rate limiter, CORS, security headers
wsgi.py             → Production gunicorn entry
```

### Response contract (always)
```python
return jsonify({"status": "ok", "data": result}), 200
return jsonify({"status": "error", "message": str(e)}), 500
```

### App factory pattern (CURRENT — don't change)
```python
# app.py uses create_app() factory — NOT direct Flask()
# Rate limiter is imported from app.py in routes:
from app import limiter

@bp.route('/api/path', methods=['POST'])
@limiter.limit("20 per minute")
def handler():
    try:
        ...
        return jsonify({"status": "ok", "data": result}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
```

### Database pattern (CURRENT — thread-safe WAL)
```python
from database import query, execute
# query() returns list[dict]
# execute() for INSERT/UPDATE/DELETE
```

### AI — OpenRouter (CURRENT models)
```python
# Chat: google/gemma-3-27b-it:free
# Scan: tries in order: google/gemma-3-12b-it:free → google/gemma-3-27b-it:free → google/gemma-4-31b-it:free
# Prompt format: merge system prompt into user message (Gemma doesn't use system role well)
# load_dotenv(override=True) in app.py — always reads fresh from .env

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
    "Content-Type": "application/json",
    "HTTP-Referer": "https://plately.app",
    "X-Title": "Plately",
}
```

### Image Scan (CURRENT — Gemma Vision, NOT Google Vision)
```python
# See routes/scan.py — full implementation
# Flow: base64 image → Gemma vision prompt → JSON ingredient list → DB match
# Falls back to mock ["chicken","eggs","garlic"] if no API key
# Partial ingredient matching: "chicken breast" → "chicken"
# If no DB match but AI returned items → returns raw AI output (up to 6)
```

### CORS
```python
CORS(app, resources={r"/api/*": {"origins": "*"}})  # dev only
# Prod: set ALLOWED_ORIGINS env var to your domain
```

---

## 🔒 SECURITY RULES
| Area | Rule |
|------|------|
| API Keys | Always `.env` via `python-dotenv`. Never in code. |
| SQL | Always parameterized queries `?` — NEVER f-strings in SQL. |
| Rate limiting | flask-limiter on all routes. /api/health exempt. |
| History DELETE | Always require user_id param — WHERE id=? AND user_id=? |
| Firebase | Only for Auth. Data in SQLite. |

---

## 🎯 DESIGN TOKENS (quick ref)
```
primaryDark  = 0xFF043B3C    creamBg    = 0xFFF0EEE9
darkText     = 0xFF083F3F    mutedText  = 0xFF7A7A7A
green        = 0xFF76CC4F    greenDark  = 0xFF3D7B20
purple       = 0xFFBA5CCC    yellow     = 0xFFEABA1C
borderGray   = 0xFFDADADA    lightGray  = 0xFFD9D9D9
red          = 0xFFD14444    orange     = 0xFFCCA04F
```
Gradients: `AppTheme.tealGradient` | `AppTheme.splashGradient`
Text styles: `AppTheme.logoStyle` | `headingLarge` | `headingMedium` | `bodyMedium` | `bodySmall` | `caption`

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
- Re-explain stack or design system
- Ask questions in separate messages
- Use `withOpacity` on const colors
- Hardcode hex values in screens
- Suggest paid APIs
- Create partial implementations

---

## 🔄 MD FILE UPDATE RULE (CRITICAL — READ THIS)
**After EVERY change in a session, Claude MUST update TASKS.md:**
- Mark completed items `[x]`
- Add new findings or bugs discovered
- Update "CURRENT STATE" section
- Add to SESSION LOG table

**If session is about to hit token limit:**
- Immediately write the next session prompt to TASKS.md under "NEXT SESSION PROMPT"
- Mark any in-progress items as `[~]` with notes on what was done so far

**MEMORY.md and SKILLS.md** — update only when architecture, tech stack, or patterns change (not every session).
