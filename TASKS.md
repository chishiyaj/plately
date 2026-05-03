# PLATELY V2 — TASKS.md
> Paste alongside MEMORY.md + SKILLS.md at the start of EVERY chat.
> Claude reads this FIRST. Before any change, read the relevant file with Desktop Commander.
> After every fix, update this file — mark [x], add to SESSION LOG.
> Last updated: Session 12 — Full accuracy pass against actual files

---

## STATUS KEY
- `[x]` = done and verified against actual files
- `[~]` = in progress / partially done
- `[ ]` = not started
- `[!]` = bug confirmed — needs fix

---

## ✅ FULLY DONE (verified Session 12)

### Backend
- [x] Flask app factory — rate limiting, CORS, security headers, structured logging
- [x] All 6 routes registered: scan, recipes, chat, goals, favorites, history
- [x] Thread-safe SQLite with WAL mode
- [x] 14 recipes seeded, 44 ingredients seeded
- [x] POST /api/scan — OpenRouter Gemma 3 Vision (FREE). Google Cloud Vision SCRAPPED.
- [x] POST /api/chat — OpenRouter Gemma 3 27B (`google/gemma-3-27b-it:free`) with conversation history (last 6 exchanges)
- [x] POST /api/recipes — ingredient matching → AI recipes + DB fallback
- [x] GET /api/recipe/<id> — full detail + ingredients + nutrition
- [x] Browse mode returns ingredients per recipe
- [x] POST /api/goals — Mifflin-St Jeor TDEE calculator
- [x] GET/POST /api/favorites — with ingredients JOIN
- [x] GET /api/favorites/check/<id>
- [x] DELETE /api/favorites/<id>
- [x] GET/POST /api/history
- [x] GET /api/history/stats
- [x] DELETE /api/history/<id> — secured with user_id
- [x] DELETE /api/history — clear all for user
- [x] GET /api/health — rate limit exempt
- [x] load_dotenv(override=True) in app.py and wsgi.py
- [x] wsgi.py — calls init_db() BEFORE create_app()
- [x] Procfile + railway.json — Railway deploy ready
- [x] Partial ingredient matching in scan
- [x] chat.py — accepts `history: [{role, content}]`, merges last 6 into OpenRouter messages

### Frontend — Auth
- [x] Firebase Auth — email/password + Google Sign-In
- [x] google-services.json in frontend/android/app/
- [x] Package name: com.plately.app (build.gradle.kts + MainActivity.kt)
- [x] minSdk 23, firebase-bom:34.0.0, firebase-auth, play-services-auth
- [x] Email verification on signup — login blocks unverified accounts
- [x] Logout — Firebase + Google sign out
- [x] Change Password — Firebase re-auth + updatePassword (Google users get friendly redirect)
- [x] Forgot Password — real AuthService.sendPasswordReset() call, success/error states
- [x] main.dart — skips splash for already-logged-in users (checks currentUser + emailVerified)

### Frontend — Data & Services
- [x] ApiService — uses Firebase UID for all history/favorites, no duplicate methods (229 lines)
- [x] ApiService.sendChat() — sends `history` list for multi-turn conversation
- [x] UserPrefsService — SharedPreferences keys namespaced by UID
- [x] UserPrefsService — daily reset: cal_consumed + protein_consumed zero out on new day (cal_date key)
- [x] AI Chat sessions stored under UID-namespaced key
- [x] auth_service.dart — present, real Firebase calls (deleted old stub version)
- [x] notification_service.dart — daily reminders + cook-done one-shot
- [x] Dead files removed: utils/ folder, old auth_service stub

### Frontend — Screens
- [x] Splash — 3 slides, editorial design, no orbs/blobs, PlatelyLogo, category tag + headline + preview widget
- [x] Login — PlatelyLogo.onDark, real Firebase auth, forgot password sheet, GoogleGLogo SVG
- [x] Signup — PlatelyLogo.onLight, email regex validation, email verification flow
- [x] Home — PlatelyLogo.onLight, profile avatar (switchTab, not push), ActivityRow shared widget, action icons: bookOpenText/bot/clockCounterClockwise
- [x] IngredientEntry — camera + type unified, 15-ingredient cap, camera freezes on capture, retake button, _addRow hidden until post-scan, scan fallback warning via _scanError
- [x] RecipeResults — ingredient matching, shimmer loading, filter chips, error/empty states
- [x] RecipeDetail — ingredients/steps tabs, nutrition card, serving scaler, Ask AI FAB, heart disabled for AI recipes (id < 0), Finish Cooking logs history + notification
- [x] Favorites — no dead back arrow, sort button, count subtitle
- [x] History — unified rows (chefHat icon always), ActivityRow shared, group labels, stats card always visible
- [x] AI Chat — no dead back arrow, sends conversation history, rich text formatting, quick prompts, typing indicator
- [x] Profile — context-aware back button (shows when pushed, hidden when tab), no "Student Plan" badge, null-safe casts, goals ctx.mounted guard, email read-only, Google user password guard, change password re-auth, TDEE auto-calc, dietary prefs, notifications toggle, help FAQ, real Firebase logout

### Frontend — Widgets & Theme
- [x] PlatelyLogo — PlatelyLogoTheme.onDark / onLight, single source of truth
- [x] GoogleGLogo — real SVG, flutter_svg, pixel-perfect four-color G
- [x] ActivityRow — shared widget used by both Home and History (zero duplication)
- [x] TapScale, RecipeCard, AiTipCard, BottomNav (replaced by main_shell)
- [x] main_shell.dart — IndexedStack, switchTab() with mounted guard, FAB unclipped via Stack(clipBehavior: Clip.none), bot icon for AI nav

### Frontend — Assets & Config
- [x] Font TTFs — all 6 present in assets/fonts/ (Nunito + DM Sans variants)
- [x] flutter_local_notifications + timezone in pubspec.yaml
- [x] firebase_core, firebase_auth, google_sign_in, flutter_svg in pubspec.yaml
- [x] flutter_markdown REMOVED from pubspec.yaml (was unused)

---

## 🐛 BUGS REMAINING

**All bugs from Sessions 1–12 are fixed.** No open bugs as of Session 12.

If new bugs are found, add them here with:
```
- [!] **BUG #N — title**
  CAUSE: ...
  FIX: ...
  FILE: ...
```

---

## ⏳ PENDING — NEXT SESSION PRIORITIES

### P0 — flutter analyze clean pass (DO THIS FIRST)
- [ ] `cd frontend && flutter pub get` (flutter_markdown removed — needs sync)
- [ ] `flutter analyze` → fix all warnings/infos → target 0 issues
- [ ] Common issues to watch: unused imports after dead file removal, missing `const`, deprecated APIs

### P1 — End-to-end testing on device
- [ ] Build debug APK: `flutter run` on real Android device
- [ ] Test full flow: Signup → verify email → login → scan → results → detail → favorite → history → profile
- [ ] Test Google Sign-In on real device (requires SHA-1 in Firebase Console)
- [ ] Test forgot password — real email delivery
- [ ] Test notifications — cook-done + daily reminder

### P2 — Backend deploy to Railway
- [ ] Push backend to GitHub (if not already)
- [ ] railway.app → New Project → Deploy from GitHub → Root: `backend`
- [ ] Set env vars: `OPENROUTER_API_KEY`, `SECRET_KEY`, `FLASK_ENV=production`
- [ ] Copy Railway URL → replace `ApiService.baseUrl` in `api_service.dart`
- [ ] Test all endpoints against deployed URL

### P3 — Release build
- [ ] `flutter build apk --release`
- [ ] Test release APK on real device (release mode disables debug overlays)
- [ ] Check ProGuard/R8 rules — Firebase Auth requires specific keep rules

### P4 — Polish pass (if time allows)
- [ ] Firebase Console → Authentication → Email Templates → sender name: "Plately"
- [ ] Add real food images to recipe seed data (currently uses network placeholder)
- [ ] History screen — wire to real backend GET /api/history (currently shows mock data)
- [ ] Home Recent Activity — wire to real backend GET /api/history (currently mock)

### P5 — GitHub
- [ ] Push when Marc says **"chishiya commit"** — branch: `dev` → PR → `main`
- [ ] Push when Marc says **"chishiya push"** — push current branch to remote

---

## 🏗️ TECH STACK (current, verified)

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) — Android target |
| Backend | Python Flask + SQLite |
| AI Chat | OpenRouter — `google/gemma-3-27b-it:free` |
| Image Scan | OpenRouter — Gemma 3 Vision (FREE). Google Vision SCRAPPED. |
| Auth | Firebase Auth (email/password + Google Sign-In) |
| Notifications | flutter_local_notifications |
| Prefs | SharedPreferences (UID-namespaced) |

---

## 🏆 PLATELY VS COMPETITORS

| Feature | MyFitnessPal | Mealime | Yummly | Plately V2 |
|---------|-------------|---------|--------|------------|
| Recipe suggestions from ingredients | ❌ | ✅ | ✅ | ✅ |
| AI chat assistant | ❌ | ❌ | ❌ | ✅ |
| Pre-cook macro awareness | ❌ | ❌ | ❌ | ✅ (USP) |
| Student budget / free | ❌ | ❌ | ❌ | ✅ |
| Philippines-specific | ❌ | ❌ | ❌ | ✅ |
| Image scan (free) | ❌ | ❌ | ❌ | ✅ Gemma Vision |
| Conversation AI memory | ❌ | ❌ | ❌ | ✅ last 6 turns |

---

## 📝 SESSION LOG

| Session | Who | What |
|---------|-----|------|
| 1 | Marc | Google logo SVG, history unified session model |
| 2 | Marc | Scan FAB alignment, history back button, Ask AI nav fix |
| 3 | Marc | flutter analyze → 0 issues |
| 4 | Marc | Goals dialog Mifflin-St Jeor auto-calc |
| 5 | Landon | Ingredient matching, new recipes, AI Chat Gemma, OpenRouter key |
| 5 | Marc | Home hero button, history empty state fix |
| 6 | Marc | Signup email verify, AI chat rich text, system prompt overhaul |
| 7 | Marc | Serving size scaler, logout Firebase, change password Firebase, favorites ingredients fix |
| 8 | Landon | Scan migrated to OpenRouter Gemma Vision (Google Vision scrapped), scan.py full rewrite |
| 8 | Marc | Auto-calc UI redesign, history stats always visible, home Start pill |
| 9 | Landon | Notifications fully wired, Railway deploy files created |
| 9 | Marc | MEMORY.md + SKILLS.md + TASKS.md full rewrite |
| 10 | Marc | Firebase Auth setup, user isolation, AI chat fixes, QA audit |
| 11 | Marc | api_service.dart deduplicated (229 lines), TASKS.md accuracy pass |
| 12 | Marc | PlatelyLogo theme system, splash redesign, history unified rows, ActivityRow shared widget, main_shell switchTab + FAB fix, profile context-aware back button, GoogleGLogo SVG, all 14 bugs fixed (see bug list above) |

---

## 🚀 NEXT SESSION PROMPT

Copy-paste this to start the next Claude chat:

```
I am Marc, sole developer of Plately V2.
Local project: C:\Users\marcd\plately-v2
Desktop Commander MCP is active — use it to read/write files directly.

[Paste MEMORY.md]
[Paste SKILLS.md]
[Paste TASKS.md]

Read TASKS.md first — it has the verified current state of every file.
All 14 bugs are fixed. Start with P0: flutter pub get + flutter analyze.
Target: 0 warnings. Fix each issue found before moving to P1 device testing.
```
