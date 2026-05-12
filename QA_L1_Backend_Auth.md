# PLATELY V2 — QA SESSION L1: Backend + Auth
> Paste alongside MEMORY.md, SKILLS.md, TASKS.md.
> Scope: Backend live tests + Auth/Onboarding flow audit.
> Keep output SHORT — one line per check. Stop after the Report section.

---

## YOUR ROLE
Senior QA engineer. Read source files via Desktop Commander, hit live endpoints.
Output a pass/fail table. Do NOT fix anything yet — report only.

---

## STEP 1 — READ THESE FILES FIRST
```
lib/main.dart
lib/services/api_service.dart
lib/services/user_prefs_service.dart
lib/screens/splash_screen.dart
lib/screens/login_screen.dart
lib/screens/signup_screen.dart
lib/screens/onboarding_goals_screen.dart
routes/chat.py
routes/scan.py
routes/recipes.py
routes/goals.py
routes/history.py
routes/favorites.py
app.py
```
Use Desktop Commander read_file on each. Note the actual file paths from your project structure.

---

## STEP 2 — LIVE BACKEND TESTS
Hit each endpoint against: https://plately-production.up.railway.app

| Endpoint | Payload | Expected |
|----------|---------|----------|
| GET /api/health | — | `{"status":"ok"}` |
| POST /api/goals | `{"weight":70,"height":175,"age":21,"sex":"male","activity":"moderate"}` | calories + protein |
| POST /api/recipes | `{"ingredients":["eggs","rice"],"user_id":"test","prefs":{}}` | array of recipes |
| POST /api/chat | `{"message":"hi","user_id":"test","history":[]}` | AI reply string |
| POST /api/scan | `{"image":"iVBORw0KGgo=","user_id":"test"}` | ingredients or graceful error |
| GET /api/history?user_id=test | — | array (empty ok) |
| GET /api/history/stats?user_id=test | — | `{total_sessions, total_recipes, sessions_this_week}` |
| GET /api/favorites?user_id=test | — | array (empty ok) |

For each: record actual status code + whether shape matches what ApiService.dart expects.

---

## STEP 3 — AUTH FLOW CODE AUDIT
From the files you read, verify:

- [ ] Splash: routes first-time users to OnboardingCarousel, returning users to MainShell
- [ ] Login: wrong credentials shows error (not crash), correct → MainShell
- [ ] Signup: email verification sent before routing to Goals
- [ ] Goals: Calculate button wired to _calculate(), result banner appears, Save uses _calGoal/_proteinGoal
- [ ] Goals: pushAndRemoveUntil used (not bare pop) → no black screen
- [ ] All fields use AppTheme.inputDecoration() — no InputBorder.none + manual Container
- [ ] No static AppTheme.darkText / AppTheme.mutedText in any TextStyle in these files
- [ ] All async gaps have `if (!mounted) return;`

---

## REPORT FORMAT (keep brief)

### Backend Results
| Endpoint | Status | Shape Match? | Issue |
|----------|--------|-------------|-------|
| ... | ... | ... | ... |

### Auth Flow
| Check | Pass/Fail | Note |
|-------|-----------|------|
| ... | ... | ... |

### 🔴 Bugs Found (if any)
- Screen | What's wrong | Root cause from code

### Verdict for L1
- PASS — proceed to L2
- FAIL — list blockers (do not fix yet, note for session prompt)
