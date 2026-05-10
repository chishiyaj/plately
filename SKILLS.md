# PLATELY V2 — SKILLS.md
> Paste alongside MEMORY.md + TASKS.md at start of every chat.
> Last updated: Session 33 — verified against source.

---

## ⚡ TOKEN BUDGET RULES
| Rule | Detail |
|------|--------|
| Complete files only | No `// ...rest stays the same` |
| One-line summary | Before any code block |
| No re-explaining MEMORY.md | Stack/design/screens are documented |
| Batch writes | Multiple related files in sequence, no chatter between |
| Max response format | Summary → code → 3 bullets → "Next:" |

---

## 🧠 ROLE
Senior Flutter/Python engineer. Goal: working demo. Priority: **runs** > **looks right** > **clean code**.

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
color: AppTheme.primaryDark         // for const static colors
color: AppTheme.cardBg(context)     // for dark-mode-aware colors
```

### Context-aware color helpers (use these in screens)
```dart
AppTheme.scaffoldBg(context)   // screen background
AppTheme.cardBg(context)       // card/surface background
AppTheme.cardAltBg(context)    // secondary card bg
AppTheme.textPrimary(context)  // primary text
AppTheme.textMuted(context)    // secondary text
AppTheme.border(context)       // border color
AppTheme.iconColor(context)    // icon tint
AppTheme.isDark(context)       // bool — true if dark mode
```

### Static colors (safe to use as const, always teal/green/brand)
```dart
AppTheme.primaryDark    AppTheme.green    AppTheme.red
AppTheme.yellow         AppTheme.purple   AppTheme.orange
AppTheme.mutedText      AppTheme.darkText AppTheme.creamBg
```

### Theme toggle
```dart
// Import from main.dart:
import '../main.dart' show themeNotifier, themeModeToString;
// Change theme:
themeNotifier.value = ThemeMode.dark;
// Persist:
final prefs = await SharedPreferences.getInstance();
await prefs.setString('app_theme_mode', themeModeToString(ThemeMode.dark));
```

### Shell / tab switching
```dart
MainShell.switchTab(shellIndex); // 0=Home, 1=Favorites, 2=AiChat, 3=Profile
// Nav bar: 0=Home, 1=Saved, 2=Scan(FAB), 3=AI, 4=Profile
```

### Fonts
- `Nunito` → logo/brand headings only
- `DM Sans` → all body, label, button text

### Packages — verified Session 33
See MEMORY.md packages table. Key additions vs old SKILLS.md:
- `permission_handler: ^11.3.1` — ADDED S33 for camera permission
- `package_info_plus: ^8.0.0` — version display in profile

### NEVER USE
- `withOpacity` on const colors → use `withValues(alpha: x)`
- `WillPopScope` → deprecated, use `PopScope`
- Hardcoded hex in screens
- Paid APIs
- `LucideIcons.alertCircle` → use `LucideIcons.circleAlert` (correct name)

### Lucide icon name gotchas
```dart
LucideIcons.circleAlert   // NOT alertCircle
LucideIcons.circleCheck   // NOT checkCircle
LucideIcons.circleX       // NOT xCircle
LucideIcons.triangleAlert // NOT alertTriangle
```

---

## 🐍 BACKEND RULES

### File structure (verified Session 33)
```
routes/scan.py      → POST /api/scan
routes/recipes.py   → POST /api/recipes + GET /api/recipe/<id>
routes/chat.py      → POST /api/chat
routes/goals.py     → POST /api/goals
routes/favorites.py → GET/POST/DELETE /api/favorites
routes/history.py   → GET/POST/DELETE /api/history + /api/history/stats + /api/history/daily
database.py         → Dual-mode PG/SQLite, ~100 recipes
app.py              → Flask factory, rate limiter, CORS, logging
wsgi.py             → gunicorn (Linux) / waitress (Windows)
```

### DB mode detection
```python
USE_PG = bool(os.getenv("DATABASE_URL", ""))
# True → PostgreSQL (Railway/Neon), ph = "%s", RETURNING id
# False → SQLite local, ph = "?"
```

### SQL placeholder (CRITICAL)
```python
from database import query, execute, PLACEHOLDER as ph
# Always:  f"INSERT INTO t (col) VALUES ({ph})", (val,)
# Never:   f"INSERT INTO t (col) VALUES (?)"  # breaks on PG
```

### Response contract
```python
return jsonify({"status": "ok",    "data": result}), 200
return jsonify({"status": "error", "message": str(e)}), 500
```

### AI — OpenRouter
```python
# Chat:       google/gemma-3-27b-it:free
# Scan:       27b → 12b → 4-31b fallback chain
# Recipe gen: google/gemma-3-27b-it:free, DB-backed 1hr cache
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
```

### history.py route order (IMPORTANT — Flask needs specific routes before parameterised)
```
GET  /api/history          → get_history
GET  /api/history/daily    → get_daily_history   ← MUST be before /<int:id>
POST /api/history          → add_history
GET  /api/history/stats    → get_history_stats
DEL  /api/history/<int:id> → delete_history_entry
DEL  /api/history          → clear_history
```

---

## 🔒 SECURITY RULES
| Area | Rule |
|------|------|
| API Keys | `.env` via `python-dotenv`. Never in code. |
| SQL | Always parameterized — use `PLACEHOLDER`. Never f-strings in values. |
| Rate limiting | flask-limiter on all routes. /api/health exempt. |
| History DELETE | Always require user_id — `WHERE id={ph} AND user_id={ph}` |
| Firebase | Auth only. Data in PostgreSQL/SQLite. |

---

## 🎯 DESIGN TOKENS (quick ref)
```
primaryDark  = 0xFF043B3C    creamBg    = 0xFFF0EEE9
darkText     = 0xFF043B3C    mutedText  = 0xFF7A7A7A
green        = 0xFF76CC4F    greenDark  = 0xFF3D7B20
purple       = 0xFFBA5CCC    yellow     = 0xFFEABA1C
borderGray   = 0xFFDADADA    red        = 0xFFD14444
orange       = 0xFFCCA04F    darkBg     = 0xFF0A1414
darkCard     = 0xFF152020    darkBorder = 0xFF2C4040
darkTextPrimary = 0xFFF0EEE9 darkTextMuted = 0xFF8AABAB
```

Gradients: `AppTheme.tealGradient` | `AppTheme.greenGradient` | `AppTheme.creamGradient`
Transitions: `AppTheme.slideUp()` | `AppTheme.zoomIn()` | `AppTheme.crossFade()` | `AppTheme.sharedAxisH()`

---

## ⚠️ CUT-OFF RECOVERY PROTOCOL
If previous session cut off mid-file:
1. Read broken file with Desktop Commander `read_file`
2. State what is complete, missing, broken
3. Continue, don't restart — append/patch only what's missing
4. Re-read after fixing to confirm complete

---

## 📋 RESPONSE FORMAT
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
- Use `withOpacity` on const colors
- Hardcode hex in screens
- Suggest paid APIs
- Partial implementations
- Use `LucideIcons.alertCircle` (wrong) — use `circleAlert`

---

## 🗂️ WHEN TO UPDATE EACH FILE

**MEMORY.md:** new screens, packages, DB changes, status changes  
**SKILLS.md:** new patterns, new NEVER USE rules, package additions  
**TASKS.md:** every single session — mark done [x], add new findings, update QA status
