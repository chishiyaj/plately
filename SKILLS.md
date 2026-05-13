# PLATELY V2 — SKILLS.md
> Paste alongside MEMORY.md + TASKS.md at start of every chat.
> Last updated: Session V start — Desktop Commander note added.

## 🖥️ DESKTOP COMMANDER (ALWAYS AVAILABLE)
Desktop Commander MCP is connected and approved. Claude can access the filesystem directly.
See MEMORY.md → "DESKTOP COMMANDER" section for full details and paths.
**Never ask the user to paste or upload files — read them directly from disk.**

---

## ⚠️ HOW TO KEEP THIS FILE ACCURATE
At the END of every session, Claude must update this file if:
- A new pattern was used that should be reused → add to the relevant section
- A new NEVER DO rule was discovered → add to NEVER DO list
- A new package was added → note usage pattern here if relevant
- A bug was caused by a wrong pattern → document the correct pattern

⚠️ COMMIT RULE: Claude must never `git commit` or `git push` without being told "chishiya commit" by the user first.

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
AppTheme.border(context)       // border color — use instead of AppTheme.borderGray
AppTheme.iconColor(context)    // icon tint
AppTheme.isDark(context)       // bool — true if dark mode
```

### Static colors (safe to use as const, always teal/green/brand)
```dart
AppTheme.primaryDark    AppTheme.green    AppTheme.red
AppTheme.yellow         AppTheme.purple   AppTheme.orange
AppTheme.mutedText      AppTheme.darkText AppTheme.creamBg
```

> ⚠️ AppTheme.mutedText and AppTheme.darkText are STATIC — they do NOT adapt to dark mode.
> NEVER use them inside a TextStyle in any widget body that renders in both light and dark mode.
> Use AppTheme.textMuted(context) and AppTheme.textPrimary(context) instead.
> NEVER use AppTheme.borderGray as a Border.all() color — use AppTheme.border(context).

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

### mounted checks (REQUIRED after every async gap)
```dart
// Always check mounted before setState or Navigator after any await
await someAsyncCall();
if (!mounted) return;
setState(() => _loading = false);

// Double-check when multiple awaits chain together:
await firstCall();
if (!mounted) return;
_doSomething();
await secondCall();
if (!mounted) return;
Navigator.pop(context);
```

### Streak and cook date — UserPrefsService (added S38)
```dart
// After a recipe is cooked — include in _finishCooking's Future.wait list:
UserPrefsService.saveLastCookDate()

// At the START of _loadPrefs() in home_screen:
await UserPrefsService.resetStreakIfExpired();

// Three methods added in S38:
// saveLastCookDate()        — saves today's date under uid_last_cook_date
// isStreakStillValid()      — true if last cook was today or yesterday
// resetStreakIfExpired()    — resets streak to 0 if isStreakStillValid() is false
```

### AlertDialog — ALWAYS use dialog context for Navigator.pop inside builder
```dart
showDialog(
  builder: (dCtx) => AlertDialog(
    title: Text('...', style: TextStyle(color: AppTheme.textPrimary(dCtx))),
    content: Text('...', style: TextStyle(color: AppTheme.textMuted(dCtx))),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dCtx, false),  // dCtx NOT context
        child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(dCtx))),
      ),
      TextButton(
        onPressed: () => Navigator.pop(dCtx, true),   // dCtx NOT context
        child: Text('Confirm'),
      ),
    ],
  ),
);
```

### Dietary prefs toggle — model convention
```dart
// pref_gluten=false means gluten-free is ACTIVE (user avoids gluten)
// pref_dairy=false means dairy-free is ACTIVE (user avoids dairy)
// When chip is turned ON (on=true), restriction becomes active → save false
case 'Gluten-Free':
  await UserPrefsService.savePrefGluten(!on);
  setState(() => _data['pref_gluten'] = !on);
case 'Dairy-Free':
  await UserPrefsService.savePrefDairy(!on);
  setState(() => _data['pref_dairy'] = !on);
```

### Packages — verified Session 40
See MEMORY.md packages table.

---

## 🐍 BACKEND RULES

### File structure (verified Session 40)
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

### history.py route order (IMPORTANT — specific before parameterised)
```
GET  /api/history          → get_history
GET  /api/history/daily    → get_daily_history   ← MUST be before /<int:id>
POST /api/history          → add_history
GET  /api/history/stats    → get_history_stats
DEL  /api/history/<int:id> → delete_history_entry
DEL  /api/history          → clear_history
```

### DELETE endpoint user_id guard (S39 — REQUIRED on all delete endpoints)
```python
user_id = (request.args.get('user_id') or '').strip()
if not user_id or user_id == 'default':
    return jsonify({"status": "error", "message": "user_id required"}), 400
```

### recipes.py prefs validation (S39)
```python
# After: if not isinstance(prefs, dict): prefs = {}
cal_goal = prefs.get("cal_goal", 2200)
protein_goal = prefs.get("protein_goal", 120)
if not isinstance(cal_goal, (int, float)) or cal_goal < 500 or cal_goal > 10000:
    prefs["cal_goal"] = 2200
if not isinstance(protein_goal, (int, float)) or protein_goal < 20 or protein_goal > 500:
    prefs["protein_goal"] = 120
for k in ("pref_veg", "pref_gluten", "pref_dairy", "pref_hipro"):
    if k in prefs and not isinstance(prefs[k], bool):
        prefs[k] = bool(prefs.get(k, False))
```

### CORS (S39 — app.py)
```python
allowed = os.getenv("ALLOWED_ORIGINS", "*").split(",")
CORS(app, origins=[o.strip() for o in allowed])
# Railway env var: ALLOWED_ORIGINS=https://plately-production.up.railway.app
```

---

## 🔒 SECURITY RULES
| Area | Rule |
|------|------|
| API Keys | `.env` via `python-dotenv`. Never in code. |
| SQL | Always parameterized — use `PLACEHOLDER`. Never f-strings in values. |
| Rate limiting | flask-limiter on all routes. /api/health exempt. |
| History DELETE | Always require user_id — reject 'default' or empty with 400 |
| Firebase | Auth only. Data in PostgreSQL/SQLite. |
| CORS | Always ALLOWED_ORIGINS env var. Never hardcode. |

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

---

## 🚫 NEVER DO
- `// ...` or `// rest stays the same`
- Re-explain stack or design system
- Use `withOpacity` on const colors → use `withValues(alpha: x)` only
- Hardcode hex in screens
- Suggest paid APIs
- Partial implementations
- Use `LucideIcons.alertCircle` (wrong) → use `LucideIcons.circleAlert`
- Use `WillPopScope` (deprecated) → use `PopScope`
- `const TextStyle(color: AppTheme.darkText)` in any widget body — not dark-mode-aware
- `const TextStyle(color: AppTheme.mutedText)` in any widget body — not dark-mode-aware
- `Border.all(color: AppTheme.borderGray)` → use `AppTheme.border(context)`
- `Navigator.pop(context)` inside a dialog builder → use the dialog's `dCtx`
- `setState()` or `Navigator.pop(context)` after an `await` without `if (!mounted) return;`
- `_ingredients = []` in the Retake button handler — only clear scan state, not typed ingredients

---

## 🗂️ WHEN TO UPDATE EACH FILE

**MEMORY.md:** new screens, packages, DB changes, status changes — update AT END OF EVERY SESSION
**SKILLS.md:** new patterns, new NEVER DO rules, package usage patterns — update when new patterns emerge
**TASKS.md:** every single session — mark done [x], add new findings, update QA status, paste next session prompt

### Lucide icon name gotchas
```dart
LucideIcons.circleAlert   // NOT alertCircle
LucideIcons.circleCheck   // NOT checkCircle
LucideIcons.circleX       // NOT xCircle
LucideIcons.triangleAlert // NOT alertTriangle
```

### PlatelyLogo widget — always use this, never raw Image.asset for logo (verified S44)
```dart
PlatelyLogo(
  theme: AppTheme.isDark(context) ? PlatelyLogoTheme.onDark : PlatelyLogoTheme.onLight,
  iconSize: 36,
  wordmarkSize: 18,
)
// On always-dark surfaces (splash, brand panel):
const PlatelyLogo(theme: PlatelyLogoTheme.onDark, iconSize: 72, wordmarkSize: 32)
```

### Goals navigation — always use pushAndRemoveUntil (verified S44)
OnboardingGoalsScreen can be the root route. Never use bare Navigator.pop() in _save().
```dart
if (Navigator.of(context).canPop()) {
  Navigator.of(context).pop();
} else {
  Navigator.of(context).pushAndRemoveUntil(
    AppTheme.fadeScale(const MainShell()),
    (route) => false,
  );
}
```

### AppTheme.inputDecoration() — use for ALL text fields (S43+)
```dart
TextField(
  decoration: AppTheme.inputDecoration(
    context: context,
    label: 'Field Label',   // OR hint: 'Placeholder'
    prefixIcon: Icon(LucideIcons.mail, size: 18, color: AppTheme.textMuted(context)),
    suffixIcon: someWidget, // optional
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), // optional
  ),
)
// Provides: OutlineInputBorder radius 12, context-aware fill/border/label/hint colors
// NEVER use InputBorder.none + manual Container for new input fields
```

### History timestamp formatting (verified S44)
Always call `.toLocal()` on `DateTime.parse()` before computing diffs.
Human format: "Today, 2:30 PM" / "Yesterday, 9:15 AM" / "Monday, 11:00 AM" / "May 3, 3:45 PM".
12-hour AM/PM, no GMT, no seconds.

### Dietary prefs — active state derivation (verified S44)
```dart
// pref_gluten=false → Gluten-Free is ACTIVE
// pref_dairy=false  → Dairy-Free is ACTIVE
final isGlutenFree = (_data['pref_gluten'] as bool?) == false;
final isDairyFree  = (_data['pref_dairy']  as bool?) == false;
// When toggling Gluten-Free ON→OFF: nextPrefVal = isGlutenFree (saves true = OFF)
// When toggling OFF→ON: nextPrefVal = isGlutenFree (saves false = ON)
```
