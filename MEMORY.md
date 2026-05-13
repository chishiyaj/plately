# PLATELY V2 — MEMORY.md
> Paste this at the START of every new Claude chat alongside SKILLS.md and TASKS.md.
> Last updated: Session Y — v1.0-rc1 APK built (63.5MB). All P0/P1 resolved. Firebase distribute + git commit pending.

## 🖥️ DESKTOP COMMANDER (ALWAYS AVAILABLE)
Claude has Desktop Commander MCP connected and approved. It can:
- Read/write/edit any file under `C:/Users/marcd/` directly — no need to upload files
- Run PowerShell commands via `start_process`
- Search files and content across the project
- The project root is `C:/Users/marcd/plately-v2/`
- Flutter frontend: `C:/Users/marcd/plately-v2/frontend/`
- Flask backend: `C:/Users/marcd/plately-v2/backend/`
- Shell is `powershell.exe`. Always use Windows-style absolute paths.
- **Do NOT ask Marc to paste file contents or upload files** — read them directly.

---

## ⚠️ HOW TO KEEP THIS FILE ACCURATE
At the END of every session, Claude must update this file to reflect exactly what changed:
- New screens or widgets built → add to SCREENS table
- New packages added → add to PACKAGES table
- DB schema changes → update DATABASE section
- Status items resolved → flip ⬜ to ✅
- New status items discovered → add as ⬜
- Tech stack changes → update TECH STACK table
Do NOT leave stale ⬜ items that were actually fixed. Do NOT mark ✅ things that were not verified.

⚠️ COMMIT RULE: Claude must never commit without being told "chishiya commit" by the user first.

---

## WHAT WE ARE BUILDING
Plately V2 — A Flutter mobile app for Android that helps students cook affordable, high-protein meals. Users scan or type ingredients, get AI recipe suggestions, see calories + protein, and track their cooking history.

**USP:** "Pre-cook macro awareness — know your protein and calories BEFORE you cook, not after."

---

## TECH STACK (VERIFIED — Session 44)

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) — Android target |
| Backend | Python Flask + dual-mode DB: PostgreSQL (prod) / SQLite (local) |
| AI Chat | OpenRouter — `google/gemma-4-31b-it:free` |
| AI Recipes | OpenRouter Gemma 4 31B — generates 5 custom recipes, 1hr DB-backed cache |
| Image Scan | OpenRouter Gemma 4 Vision — fallback chain (4-31b → 4-26b → llama-3.3-70b) |
| Auth | Firebase Auth (Email/Password + Google Sign-In) ✅ |
| Notifications | flutter_local_notifications — 5 dynamic scheduled + 1 cook-done one-shot |
| Prefs | SharedPreferences — UID-namespaced, daily macro reset on new day |
| Prod Server | gunicorn (Linux) / waitress (Windows) — wsgi.py auto-detects OS |
| Deploy | Railway — railway.json + Nixpacks, Neon PostgreSQL |

---

## DESIGN SYSTEM

| Token | Value |
|-------|-------|
| primaryDark | #043B3C |
| creamBg | #F0EEE9 |
| darkText | #043B3C |
| mutedText | #7A7A7A |
| green | #76CC4F |
| purple | #BA5CCC |
| yellow | #EABA1C |
| red | #D14444 |
| darkBg (dark mode) | #0A1414 |
| darkCard | #152020 |
| darkTextPrimary | #F0EEE9 |
| Font brand | Nunito |
| Font UI | DM Sans |

---

## SCREENS (ALL BUILT ✅)
1. `splash_screen.dart` — single branded splash (~1.8s) + OnboardingCarousel for first-time users only
2. `login_screen.dart` — email + password + Google, dark-mode-aware _AuthField, forgot password clarification
3. `signup_screen.dart` — username + email + password + Google + email verification, dark-mode-aware _field()
4. `home_screen.dart` — greeting, hero CTA, calendar macro widget, macro rings, action row, suggested recipes, recent activity
5. `recipe_results_screen.dart` — grid, shimmer (dark-mode-aware), filters, search bar, error state, offline banner
6. `recipe_detail_screen.dart` — ingredients/steps tabs, serving scaler, nutrition card, Ask AI FAB, share card, finish cooking
7. `favorites_screen.dart` — search bar, category filters, recipe grid
8. `history_screen.dart` — stats card, weekly calendar (Mon–Sun bars + prev/next nav), human timestamps, entry tap opens correct recipe, grouped entries, delete, Cook Again
9. `ai_chat_screen.dart` — chat bubbles, quick chips, initialPrompt, red error bubble for ERROR: prefix, dark-mode welcome subtitle
10. `profile_screen.dart` — avatar, stats, goals card, dietary prefs (correct toggle logic + High Protein explanation), theme picker (icon+label rows), settings
11. `pantry_screen.dart` — name/quantity/unit/always-stocked, AppTheme.inputDecoration() field, SharedPreferences
12. `shopping_list_screen.dart` — auto from recipes, pantry cross-ref, Shopee deep-link (opens shopee.ph in browser; copies single item name only as last resort)
13. `ingredient_entry_screen.dart` — camera (permission_handler, error overlay, loading spinner, lifecycle retry) + type mode
14. `onboarding_goals_screen.dart` — body stats + fitness goal, Mifflin-St Jeor TDEE via /api/goals, pushAndRemoveUntil fix, dark-mode-aware fields

---

## KEY WIDGETS
- `PlatelyLogo` — brand logo widget with onDark/onLight theme variants; used in appbars + splash
- `GoogleGLogo` — SVG Google G for sign-in buttons
- `TapScale` — scale-on-press wrapper used throughout
- `PlatelyShareCard` — screenshot-able card for streak/recipe sharing
- `ActivityRow` — home screen recent activity row
- `RecipeCard` — recipe grid card with shimmer support

---

## NAVIGATION
- Bottom nav: Home | Favorites | [Scan FAB] | AI Chat | Profile
- Shell tab indices: 0=Home, 1=Favorites, 2=AiChat, 3=Profile
- `MainShell.switchTab(n)` — static method
- Scan FAB: clean circle with LucideIcons.scanLine, no label

---

## API ENDPOINTS

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/scan | base64 → ingredients[] via Gemma vision |
| POST | /api/recipes | browse DB or AI-generate 5 recipes |
| GET | /api/recipe/\<id\> | recipe detail + nutrition + ingredients |
| POST | /api/chat | message → Gemma reply |
| POST | /api/goals | Mifflin-St Jeor TDEE |
| GET/POST | /api/favorites | get/add (includes ingredient list) |
| GET | /api/favorites/check/\<id\> | is saved? |
| DELETE | /api/favorites/\<id\> | unsave |
| GET/POST | /api/history | get/add history |
| GET | /api/history/stats | total_sessions, total_recipes, sessions_this_week |
| GET | /api/history/daily | ?user_id=&date=YYYY-MM-DD → daily macro summary |
| DELETE | /api/history/\<id\> | delete entry (requires user_id as query param) |
| DELETE | /api/history | clear all (requires user_id as query param) |
| GET | /api/health | health check |

---

## DATABASE (Neon PostgreSQL prod / SQLite local)

Tables: `ingredients` (~84), `recipes` (~100), `recipe_ingredients`, `nutrition` (has cost_php), `history` (has calories_logged, protein_logged, recipe_id, recipe_name), `favorites`, `ai_recipe_cache`

Recipe filters (tags): `Asian | Italian | Vegetarian | Low-Cal | High-Protein | Filipino`

~100 seeded recipes including 20 Filipino staples + 40 regional Filipino + budget Asian.

---

## PACKAGES (pubspec.yaml — verified Session 44)

| Package | Purpose |
|---------|---------|
| `flutter_animate` | animations |
| `lucide_icons_flutter` | icons |
| `shimmer` | skeleton loading |
| `glassmorphism` | frosted glass |
| `camera` | viewfinder |
| `permission_handler: ^11.3.1` | camera permission |
| `animations` | SharedAxisTransition |
| `flutter_svg` | Google G logo |
| `firebase_core`, `firebase_auth`, `google_sign_in` | auth |
| `flutter_local_notifications`, `timezone` | notifications |
| `cached_network_image` | recipe images |
| `flutter_markdown` | AI chat markdown |
| `fl_chart` | charts |
| `url_launcher` | Shopee links |
| `screenshot` + `share_plus` | share card |
| `package_info_plus: ^8.0.0` | version display |
| `image_picker`, `shared_preferences`, `sqflite`, `http`, `path` | core |

---

## CURRENT SETUP STATUS (Last updated: Session K+H)

| Item | Status |
|------|--------|
| flutter analyze | ✅ 0 issues (verified SK+H) |
| Firebase Auth (email + Google) | ✅ |
| google-services.json | ✅ |
| Font TTF files (6) | ✅ |
| Backend live on Railway | ✅ https://plately-production.up.railway.app |
| Neon DB connected + seeded | ✅ ~100 recipes |
| Landing page | ✅ https://chishiyaj.github.io/plately |
| cron-job.org keepalive | ✅ every 10 min |
| GitHub Actions CI/CD | ✅ distribute.yml |
| APK keystore | ✅ upload-keystore.jks (path fixed: ../upload-keystore.jks) |
| themeNotifier (ValueNotifier) | ✅ main.dart top-level |
| Dark mode themes + helpers | ✅ app_theme.dart |
| Theme toggle on Profile | ✅ icon+label rows (Light/Dark/System) with checkmark |
| AppTheme.inputDecoration() helper | ✅ added S43 — consistent OutlineInputBorder radius 12 |
| permission_handler in pubspec | ✅ |
| Camera permission flow | ✅ explicit request, error overlay, lifecycle retry |
| AI chat error bubble (red) | ✅ |
| ai_chat_screen circleAlert icon | ✅ |
| history.py duplicate route | ✅ FIXED S33 |
| Dark mode regressions (all screens) | ✅ FIXED S35–S43 |
| _buildMacroRings() dead method | ✅ DELETED S36 |
| history_screen _clearAll() dCtx | ✅ FIXED S36 |
| _finishCooking() mounted checks | ✅ FIXED S36 |
| Dietary pref toggle inversion | ✅ FIXED S36 + verified S44 |
| Retake button wipes ingredients | ✅ FIXED S36 |
| Calendar forward arrow upper bound | ✅ FIXED S36 |
| Streak reset on missed days | ✅ FIXED S38 |
| Shopee fallback copies single item | ✅ FIXED S38 |
| Pull-to-refresh re-syncs macros | ✅ FIXED S38 |
| _loadHistory() try/catch | ✅ FIXED S38 |
| history.py DELETE guards | ✅ FIXED S39 |
| api_service.dart DELETE query param | ✅ VERIFIED S39 |
| app.py CORS ALLOWED_ORIGINS | ✅ FIXED S39 |
| recipes.py prefs validation | ✅ FIXED S39 |
| chat.py rate limit key | ✅ VERIFIED S39 |
| chat.py error logging + OpenRouter guards | ✅ FIXED S43 |
| Splash → single branded + first-time carousel | ✅ VERIFIED S44 |
| Login _AuthField dark-mode-aware | ✅ VERIFIED S44 |
| Signup _field() dark-mode-aware | ✅ VERIFIED S44 |
| Goals P0 black screen (pushAndRemoveUntil) | ✅ VERIFIED S44 |
| Goals sex selector aligned (Expanded, height 44) | ✅ VERIFIED S44 |
| Goals TDEE reflects in targets (setState) | ✅ VERIFIED S44 |
| Scan FAB clean (no garbled label) | ✅ VERIFIED S44 |
| History human timestamps | ✅ VERIFIED S44 |
| History entry tap opens correct recipe | ✅ VERIFIED S44 |
| History weekly calendar Mon–Sun | ✅ VERIFIED S44 |
| Profile Gluten/Dairy toggle correct | ✅ VERIFIED S44 |
| Profile High Protein explanation | ✅ VERIFIED S44 |
| Profile theme picker icon+label rows | ✅ VERIFIED S44 |
| Pantry inputDecoration consistent | ✅ VERIFIED S44 |
| Release APK built (64MB) | ✅ v1.0.0+2 built S-Y — 63.5MB |
| Pushed to main + GitHub Actions | ✅ S40 |
| ALLOWED_ORIGINS Railway var set | ✅ Marco confirmed — kept as * (correct for mobile) |
| Firebase App Distribution testers | ✅ S45 — tester emails added |
| Google Sign-In release SHA-1 | ✅ Marc confirmed added to Firebase Console |
| Session C fixes (recipe_detail, browse, shopping) | ✅ DONE S45 |
| Session D fixes (camera, scan dark mode, ai_chat dupes) | ✅ DONE S45 |
| Profile dietary prefs redesign (toggle rows + animated pill) | ✅ DONE SK |
| Static color violations cleared (all screens) | ✅ DONE SK+H — flutter analyze 0 issues |
| Launcher icon redesign (green→teal gradient + ring mark) | ✅ DONE SH — all mipmap + drawable densities |
| Goals screen static color violations fixed | ✅ DONE SH |
| Session H remaining (Home dark, Favorites, activity_row) | ✅ DONE SI — borderGray fix, RecipeCard heart badge, _Stat color |
| Backend | All APIs need live verification — chat, scan, recipes, goals, history | ✅ DONE SK — all passing; chat/scan model updated to gemma-4-31b |

---

## API CONNECTION
`ApiService.baseUrl` reads from `--dart-define=PLATELY_API_URL` at build time.
- Emulator: `flutter run` → `http://10.0.2.2:5000`
- Physical device: `flutter run --dart-define=PLATELY_API_URL=http://192.168.x.x:5000`
- Production: `flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-production.up.railway.app`

---

## TEAM
| Name | Role |
|------|------|
| Marc | Frontend (Flutter) |
| Marco | Backend (Flask, DB) |
| Landon | AI & Data |
| Adrian | QA & Docs |
