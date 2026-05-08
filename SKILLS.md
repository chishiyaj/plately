# PLATELY V2 — SKILLS.md (GOD TIER)
> Paste alongside MEMORY.md + TASKS.md at start of every chat.
> Last updated: Session 7 — verified against pubspec.yaml and source.

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
| Skip boilerplate comments | No `// Flutter SDK`, `// material.dart` comments. |

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

### Shell / tab switching pattern
```dart
// Switch tabs from anywhere:
MainShell.switchTab(shellIndex); // 0=Home, 1=Favorites, 2=AiChat, 3=Profile
// Nav bar indices: 0=Home, 1=Saved, 2=Scan(FAB), 3=AI, 4=Profile
```

### Fonts
- `Nunito` → logo and brand headings only
- `DM Sans` → all body, label, button text

### Packages in use (pubspec.yaml — verified Session 7)
- `flutter_animate` — chainable animations
- `lucide_icons_flutter` — icons (not Material)
- `shimmer` — skeleton loading
- `glassmorphism` — frosted glass
- `camera` — live camera viewfinder
- `animations` — SharedAxisTransition
- `flutter_svg` — Google G logo
- `firebase_core`, `firebase_auth`, `google_sign_in` — auth
- `flutter_local_notifications`, `timezone` — notifications
- `cached_network_image` — recipe image URLs
- `flutter_markdown` — markdown in AI chat responses (**in pubspec, not removed**)
- `fl_chart` — macro dashboard bar chart
- `url_launcher` — Shopee deep-links from shopping list
- `screenshot` + `share_plus` — recipe share card
- `image_picker`, `shared_preferences`, `sqflite`, `http`, `path` — core

### NEVER USE
- `withOpacity` on const colors → use `withValues(alpha: x)`
- `WillPopScope` → deprecated
- Hardcoded hex in screens
- Paid APIs

---

## 🐍 BACKEND RULES

### File structure (ACTUAL — verified Session 7)
```
routes/scan.py      → POST /api/scan (Gemma vision, partial match, fallback chain)
routes/recipes.py   → POST /api/recipes (DB browse OR AI-gen 5 recipes, 1hr cache, tag normaliser)
routes/chat.py      → POST /api/chat (Gemma 3 27B, system merged into user msg)
routes/goals.py     → POST /api/goals (Mifflin-St Jeor)
routes/favorites.py → GET/POST/DELETE /api/favorites (full ingredient list in response)
routes/history.py   → GET/POST/DELETE /api/history (DELETE requires user_id)
database.py         → Dual-mode PostgreSQL (prod) / SQLite (local), 34 recipes, ~84 ingredients
app.py              → Flask factory, structured logging, rate limiter, CORS, security headers
wsgi.py             → waitress (Windows) / gunicorn (Linux) auto-detects OS
railway.json        → Nixpacks, python wsgi.py start command
_seed_data.py       → Standalone seed script (run manually if DB needs reset)
```

### Database mode detection
```python
# database.py — reads DATABASE_URL env var
USE_PG = bool(os.getenv("DATABASE_URL", ""))
# If True  → PostgreSQL (Render/Railway), uses psycopg2, PLACEHOLDER = "%s", RETURNING id
# If False → SQLite at backend/db/plately.db, uses sqlite3, PLACEHOLDER = "?"
```

### SQL placeholder pattern (CRITICAL — must use PLACEHOLDER variable)
```python
from database import query, execute, PLACEHOLDER as ph

# WRONG — breaks on PostgreSQL
execute("INSERT INTO history (user_id) VALUES (?)", (uid,))

# RIGHT — works on both
execute(f"INSERT INTO history (user_id) VALUES ({ph})", (uid,))
```

### Response contract (always)
```python
return jsonify({"status": "ok", "data": result}), 200
return jsonify({"status": "error", "message": str(e)}), 500
```

### App factory pattern (CURRENT — don't change)
```python
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

### AI — OpenRouter (CURRENT models)
```python
# Chat:      google/gemma-3-27b-it:free
# Scan:      tries 27b → 12b → 4-31b (fallback chain, first non-429 wins)
# Recipe gen: google/gemma-3-27b-it:free — 1hr in-memory cache by fingerprint
# Prompt: merge system into user message (Gemma doesn't handle system role well)
# load_dotenv(override=True) in app.py — always reads fresh from .env

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
    "Content-Type": "application/json",
    "HTTP-Referer": "https://plately.app",
    "X-Title": "Plately",
}
```

### Recipe tags (valid values — client filter depends on these exact strings)
```
"Asian" | "Italian" | "Vegetarian" | "Low-Cal" | "High-Protein" | "Filipino"
```
Tag normaliser in `recipes.py` maps aliases ("high protein" → "High-Protein", etc.)

### CORS
```python
# Dev: origins="*"
# Prod: set ALLOWED_ORIGINS env var to Railway domain
allowed_origins = os.getenv("ALLOWED_ORIGINS", "*" if IS_DEV else "")
CORS(app, resources={r"/api/*": {"origins": allowed_origins}})
```

---

## 🔒 SECURITY RULES
| Area | Rule |
|------|------|
| API Keys | Always `.env` via `python-dotenv`. Never in code. |
| SQL | Always parameterized — use `PLACEHOLDER` variable, NEVER f-strings in values. |
| Rate limiting | flask-limiter on all routes. /api/health exempt. |
| History DELETE | Always require user_id — WHERE id={ph} AND user_id={ph} |
| Firebase | Auth only. All data in PostgreSQL/SQLite. |

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
- Partial implementations

---

## 🔄 MD FILE UPDATE RULE (CRITICAL)
**After EVERY change in a session, Claude MUST update TASKS.md:**
- Mark completed items `[x]`, move to correct `COMPLETED — SESSION N` block
- Add new bugs/findings to BACKLOG
- Update "CURRENT STATE" section with accurate counts and flags
- Add row to SESSION LOG

**If hitting token limit:** Write next session prompt to TASKS.md under "NEXT SESSION — START HERE", mark in-progress as `[~]`

---

## ⚠️ CUT-OFF RECOVERY PROTOCOL
If the previous session was cut off mid-file (token limit hit while writing code), the file on disk may be half-written and broken. Always follow this before continuing:

1. **Read the broken file first:**
   Use Desktop Commander `read_file` on every file that was being edited
2. **Diagnose out loud:**
   State what is complete, what is missing, and what is syntactically broken
3. **Continue, don't restart:**
   Append or patch only what's missing — do not rewrite correct sections
4. **Verify after:**
   After fixing, re-read the file and confirm it is complete and valid

**Recovery prompt template (user pastes this):**
```
Last session cut off mid-task. Before doing anything:
1. Read current state of [filename] with Desktop Commander
2. Tell me what's complete, what's broken, what's missing
3. Continue from exactly where it stopped — do not restart

Task that was cut: [describe what was being done]
```

---

## 💡 EFFICIENT PROMPTING RULES (for Marc/team)
To save tokens and get better responses:

**DO:**
- State the exact filename and function name — never make Claude guess
- Paste the error message verbatim if there is one
- One task per message — multi-asks produce rushed output
- Put hard constraints first ("Full file only. No hex. DM Sans.")
- Trust the .md files — don't re-explain the stack in your prompt

**DON'T:**
- Re-explain what Plately is or what the stack is — it's in MEMORY.md
- Say "you might want to" or "maybe consider" — be direct
- Ask Claude to fix AND add AND update in one message
- Paste all 3 .md files if you only need a single isolated fix (SKILLS + TASKS is enough for frontend-only sessions)

**Minimum viable prompt for a fix:**
```
[SKILLS.md] [TASKS.md]
Fix: [symptom in one sentence]
File: [exact filename]
Error: [paste error if any]
Full file output, no partials.
```

---

## 🗂️ WHEN TO UPDATE EACH FILE

**Update MEMORY.md when:**
- Recipe / ingredient counts change
- New screens or widgets are added
- New packages added to pubspec
- Setup status changes (❌ → ✅)
- DB schema changes

**Update SKILLS.md when:**
- New package added to pubspec
- Backend pattern changes (new model, new route structure)
- New NEVER USE rule discovered
- DB mode or deployment config changes

**Update TASKS.md:** every single session, no exceptions.
