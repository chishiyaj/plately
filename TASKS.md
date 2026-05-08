## CURRENT STATE (Session 32 — 🔴 IN PROGRESS)
Full audit complete. 6 fix sessions queued below. Execute in order: E → A → B → C → D → F.

### Issues confirmed from source audit:
- AI (recipes + chat): Both endpoints work in isolation but OpenRouter free-tier rate limits + no error surfacing in Flutter cause silent empty states
- Camera: `_initCamera()` silently falls to type mode on permission/init error — no runtime permission prompt, no error UI
- Dark mode: Was implemented in S12/S13 but colors still break — text invisible, buttons disappear
- Theme toggle: Not present on profile screen — no user control over Dark/Light/System
- Macro sync: `user_prefs_service.dart` keys are correct (cal_goal, protein_goal) BUT onboarding_goals_screen may not write weight/height/age/sex, and profile_screen may not refresh in didChangeDependencies
- Home history widget: Still a separate section, not merged into macros card with date selector
- General UI: Emoji still in some screens, recipe detail nutrition card cramped, history cards oversized

---

## SESSION 32 — FIX QUEUE (execute in this order)

### ⚡ PROMPT E — AI Recipe Gen + Chat Fix (RUN FIRST — P1)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

Both AI systems return nothing to the user — recipe generation and AI chat both fail silently. From source audit, the backend code looks correct structurally but OpenRouter free-tier 429s and response edge cases are not surfaced to Flutter.

Fix the following — read each file with Desktop Commander first:

BACKEND — backend/routes/recipes.py:
1. In _generate_ai_recipes(): add logger.info("Raw OpenRouter response: %s", raw) BEFORE the markdown fence stripper — this lets Railway logs show us exactly what OpenRouter returned
2. The current cache stores empty results on parse error — add guard: only call _cache_set() if len(cleaned) > 0
3. On 429 HTTPError from OpenRouter, return a proper {"status": "error", "message": "AI busy — showing saved recipes instead"} to Flutter rather than silently falling to DB fallback with no indicator
4. In get_recipes() endpoint: when ai_recipes is empty AND db fallback also returns empty, return status="error" with message="No recipes found for those ingredients" so Flutter can show it

BACKEND — backend/routes/chat.py:
1. In _ask_ai(): add logger.info("Raw OpenRouter chat response: %s", reply[:200]) after the reply is extracted
2. The system prompt is merged into user message only when no history — when history IS present, the first message role is "user" with content=SYSTEM_PROMPT, but OpenRouter/Gemma may reject assistant role in history. Add a filter: only include history messages where role == "user" OR role == "assistant" AND ensure no consecutive same-role messages (Gemma constraint)
3. Confirm max_tokens=450 is not cutting off recipe list responses — raise to 600

FLUTTER — frontend/lib/services/api_service.dart:
1. Read the file. In getRecipes(): when response status == "error", throw an exception with the message string instead of returning [] — so RecipeResultsScreen can catch and display it
2. In sendChat(): when response status == "error", return the error message string so AiChatScreen can show it in a red bubble

FLUTTER — frontend/lib/screens/recipe_results_screen.dart:
1. Read the file. Wrap the AI recipe fetch in try/catch. On error, show a centered error widget: red icon + error message text + "Try Again" button that retries the fetch
2. Show a different empty state for "AI busy" vs "no matches" — if error message contains "busy" show "AI is busy, showing saved recipes" and trigger DB browse mode

FLUTTER — frontend/lib/screens/ai_chat_screen.dart:
1. Read the file. When sendChat returns an error string (starts with "error:" or is caught exception), display it as a chat bubble with red-tinted background instead of nothing

Read every file with Desktop Commander before editing. Full files only. No partials.
After all files done: flutter analyze mentally and list any issues.
```

---

### ⚡ PROMPT A — Camera Scanner Fix (RUN SECOND — P1)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

The camera viewfinder in ingredient_entry_screen.dart is completely blank. The user sees nothing when switching to camera mode.

Source audit findings:
- _initCamera() silently catches ALL errors and falls to type mode — user never knows camera failed
- permission_handler is NOT in pubspec.yaml — camera package handles permission via camera.initialize() throwing CameraException
- AndroidManifest.xml has CAMERA permission declared — that part is correct
- The CameraPreview IS conditionally rendered: only if (_camReady && _cam != null) — so if _camReady never becomes true, nothing shows
- The catch in _initCamera() sets _mode = _Mode.type but never sets an error state the user can act on

Fix ingredient_entry_screen.dart:
1. In _initCamera(): catch CameraException specifically. If it's a permission error (e.description contains 'permission' or 'denied'), set a new state bool _camPermissionDenied = true and show an error UI instead of silently switching to type mode
2. Add a _camError String? state. On any camera init failure, set _camError to a human-readable message
3. In the build() camera layer: if _camError != null, show an error card overlay (dark background, lock icon, error text, "Grant Camera Access" button that calls _initCamera() again)
4. In _cameraContent() / wherever the viewfinder area is built: if !_camReady and _camError == null, show a centered CircularProgressIndicator (white, size 32) while camera initializes — not a blank screen
5. After _cam!.initialize() succeeds, add a check: if (!mounted) return; before setState — already present but verify
6. Add didChangeAppLifecycleState: if state == AppLifecycleState.resumed and !_camReady, call _initCamera() again
7. The _isDark getter checks _mode == _Mode.camera — this means camera UI style applies even when camera fails. Fix: bool get _isDark => _mode == _Mode.camera && (_camReady || _camError != null)

Also add permission_handler: ^11.3.1 to pubspec.yaml dependencies. Then in _initCamera(), before availableCameras(), call:
  final status = await Permission.camera.request();
  if (!status.isGranted) { setState(() { _camPermissionDenied = true; }); return; }

Read ingredient_entry_screen.dart and pubspec.yaml with Desktop Commander first. Full files only.
```

---

### ⚡ PROMPT B — Dark Mode Overhaul + Theme Toggle (RUN THIRD — P1)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

Dark mode is broken — text is invisible, buttons can't be seen. There is also no way for users to toggle Dark/Light/System.

Read app_theme.dart, main.dart, and profile_screen.dart with Desktop Commander first.

Fix 1 — main.dart:
- Add a ValueNotifier<ThemeMode> at the top level (outside any class): final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
- On app start in main(), read SharedPreferences key 'app_theme_mode' (values: 'light', 'dark', 'system') and set themeNotifier.value accordingly
- Wrap MaterialApp in ValueListenableBuilder<ThemeMode> — pass themeNotifier.value to MaterialApp's themeMode parameter
- Export themeNotifier so other files can import it: make it a top-level variable in main.dart

Fix 2 — app_theme.dart:
- Add a static ThemeData darkTheme() method that returns ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D1F1F),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF76CC4F),
      surface: const Color(0xFF1A2E2E),
      onSurface: const Color(0xFFEDEAE4),
      surfaceContainerHighest: const Color(0xFF1F3535),
    ),
  )
- Add helper static methods that are context-aware (use Theme.of(context)):
    static Color cardBg(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1A2E2E) : Colors.white;
    static Color border(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF2E4A4A) : const Color(0xFFDADADA);
    static Color textPrimary(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFFEDEAE4) : darkText;
    static Color textMuted(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF9BB5B5) : mutedText;
    static Color screenBg(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF0D1F1F) : creamBg;
- Pass darkTheme() to MaterialApp's darkTheme parameter in main.dart

Fix 3 — profile_screen.dart:
- Add a "Display" section in the settings list with three segmented options: Light / Dark / System
- Implement as a Row of three TapScale containers (pill style, selectedBg = primaryDark/white text, unselected = transparent/border)
- On tap: save to SharedPreferences key 'app_theme_mode', then set themeNotifier.value = ThemeMode.light/dark/system
- Import main.dart's themeNotifier
- Show the current selection by reading themeNotifier.value

Fix 4 — Go through these screens and replace any hardcoded Color() or AppTheme.creamBg/darkText used directly (not via context) with the context-aware helpers above:
home_screen.dart, recipe_results_screen.dart, recipe_detail_screen.dart, ai_chat_screen.dart, history_screen.dart, favorites_screen.dart, pantry_screen.dart

Read each screen file with Desktop Commander. For each: find hardcoded colors → replace with AppTheme.cardBg(context), AppTheme.textPrimary(context), AppTheme.screenBg(context), AppTheme.border(context). Full files only.
```

---

### ⚡ PROMPT C — Macro Sync + Goals UI Fix (RUN FOURTH — P1)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

Two bugs: (1) Goals set in onboarding don't reflect in profile Edit Goals. (2) Edit Goals UI displays badly.

Read user_prefs_service.dart, onboarding_goals_screen.dart, and profile_screen.dart with Desktop Commander first.

SOURCE AUDIT CONTEXT — user_prefs_service.dart keys confirmed:
- cal_goal (int) — calorie goal
- protein_goal (int) — protein goal  
- fitness_goal (String) — 'lose'/'maintain'/'gain'
- pref_veg, pref_gluten, pref_dairy, pref_hi_pro (bool)
NOTE: weight, height, age, sex are NOT stored in UserPrefsService — check if onboarding_goals_screen.dart stores them somewhere else. If it stores them under different keys, standardize.

Fix 1 — user_prefs_service.dart:
- Add missing keys and methods if onboarding_goals_screen.dart writes weight/height/age/sex:
    static const _kWeight = 'weight_kg';
    static const _kHeight = 'height_cm';
    static const _kAge    = 'age_years';
    static const _kSex    = 'sex'; // 'male'/'female'
    static Future<void> saveWeight(double v) async => ...
    static Future<void> saveHeight(double v) async => ...
    static Future<void> saveAge(int v) async => ...
    static Future<void> saveSex(String v) async => ...
- Add these to the load() return map as well

Fix 2 — onboarding_goals_screen.dart:
- Confirm it calls saveCalGoal(), saveProteinGoal(), saveGoal(), setOnboardingDone()
- If it has weight/height/age/sex fields, make sure it calls the new save methods above
- On skip: still call setOnboardingDone() but keep defaults

Fix 3 — profile_screen.dart Edit Goals section:
- In initState AND didChangeDependencies: call UserPrefsService.load() and setState with results — so navigating back to profile always shows fresh values
- Redesign the Edit Goals card:
  - Full-width card with 16px padding, rounded corners, AppTheme.cardBg(context) background
  - 4 rows: Calories, Protein, Carbs, Fat — each row: [colored icon] [label] [spacer] [current value] [edit icon]
  - Tap any row → showModalBottomSheet with a numeric TextField pre-filled with current value
  - Bottom sheet: title + TextField (keyboardType: numeric) + "Save" button
  - Calorie row subtitle: "TDEE: Xkcal" shown in mutedText if TDEE was calculated
  - Weight / Height / Age / Sex fields: show as a second card "Body Stats" with same tap-to-edit pattern
- Remove any emoji from section headers
- Use AppTheme.textPrimary(context), AppTheme.cardBg(context), AppTheme.border(context) throughout

Read all three files with Desktop Commander. Full files only. No partials.
```

---

### ⚡ PROMPT D — Home Macro + History Combined Widget (RUN FIFTH — P2)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

The history widget on home_screen.dart is too large and separate from the macro section. Merge them into one unified card with a date selector.

Read home_screen.dart and backend/routes/history.py with Desktop Commander first.

BACKEND — backend/routes/history.py:
Add a new endpoint GET /api/history/daily?user_id=X&date=YYYY-MM-DD that:
- Queries the history table for all entries WHERE user_id = ? AND DATE(timestamp) = ?
- Returns: { total_calories: int, total_protein: int, recipes: [list of recipe name strings], meal_count: int }
- Uses PLACEHOLDER variable (not hardcoded ?) — check existing history.py pattern
- If no entries for that date: return { total_calories: 0, total_protein: 0, recipes: [], meal_count: 0 }
- Register the new endpoint in the blueprint

FLUTTER — frontend/lib/services/api_service.dart:
Add method:
  static Future<Map<String, dynamic>> getDailyHistory(String userId, String date) async {
    // GET /api/history/daily?user_id=...&date=...
    // Returns map with total_calories, total_protein, recipes, meal_count
    // On error return empty map with zeros
  }

FLUTTER — home_screen.dart — redesign the macro+history card:
Replace the separate history section and macro section with ONE combined card:

Card structure:
- Card header: Row with "My Progress" (left, DM Sans Bold 15) + date strip (right)
- Date strip: horizontal scrollable row of 7 date pills (Mon dd format), today selected by default, highlighted with primaryDark background + white text, others ghost/outline
- Tapping a date pill: call getDailyHistory() for that date, setState with result
- Below date strip: 4 macro rings/bars — for TODAY use existing _calConsumed/_proteinConsumed from prefs. For past dates use API result
- Below macros: "Meals" row — if recipes list is non-empty show up to 3 recipe name chips (small, green tint), then "+N more" if overflow. If empty: "No meals logged" in mutedText, 12px

State to add:
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dailyData = {};  // filled by getDailyHistory for non-today dates
  bool _loadingDaily = false;

Remove: the old separate ActivityRow / history section widget from home_screen.dart
Keep: streak pill, update banner, wakeup banner, recipe suggestions section

Full files only. No partials.
```

---

### ⚡ PROMPT F — Full UI Polish Pass (RUN LAST — P2)
**Paste this into a new Claude chat with MEMORY.md + SKILLS.md:**

```
[MEMORY.md] [SKILLS.md]

Final UI polish pass — fix all remaining visual issues. Read each file with Desktop Commander before editing.

Fix 1 — EMOJI REMOVAL (all screens):
Replace every emoji with lucide_icons_flutter equivalent. Common mappings:
🔥 → LucideIcons.flame   ✅ → LucideIcons.checkCircle   💪 → LucideIcons.dumbbell
🍳 → LucideIcons.chefHat  ⚡ → LucideIcons.zap  📊 → LucideIcons.barChart2
🎯 → LucideIcons.target  🛒 → LucideIcons.shoppingCart  ❤️ → LucideIcons.heart
Scan every screen file: home_screen.dart, profile_screen.dart, history_screen.dart, recipe_detail_screen.dart, pantry_screen.dart, shopping_list_screen.dart, ai_chat_screen.dart

Fix 2 — history_screen.dart — compact history cards:
Current cards are too tall. Redesign each entry as a ListTile-style row:
- Height: max 64px per entry
- Left: date in small mutedText (MMM dd, h:mm a format)
- Center: recipe names joined with "·" separator, maxLines:1, overflow:ellipsis
- Right: Column with calories in green (small badge) + protein in purple (small badge)
- Remove any padding > 12px vertical

Fix 3 — recipe_detail_screen.dart — nutrition card:
Replace the current nutrition layout with a 2×2 grid:
- Each cell: colored circle dot (8px) + macro value (20px bold) on top, label (11px mutedText) below
- Grid spacing: 8px gap, equal width cells
- Add ₱ cost row below grid if costPhp > 0: "~₱X per serving" in yellow/orange text, small
- Serving scaler stays where it is

Fix 4 — recipe_results_screen.dart + favorites_screen.dart — recipe card contrast:
- Recipe card: ensure name text uses AppTheme.textPrimary(context), not hardcoded darkText
- Protein badge: white text on green — confirm contrast is sufficient (it is)
- Cost chip: dark orange text on light yellow — confirm not white-on-white in dark mode
- Recipe name: maxLines: 2, overflow: TextOverflow.ellipsis — confirm this is set

Fix 5 — home_screen.dart — after Prompt D applied:
- Remove any leftover emoji from greeting text or section headers
- Ensure streak pill uses LucideIcons.flame not 🔥
- "Start Cooking" CTA: verify background is AppTheme.primaryDark, text is white, font is DM Sans Bold

After ALL fixes: do a full mental flutter analyze pass. List any type errors, missing imports, or deprecated APIs you spot.

Full files only. No partials.
```

---

## CURRENT STATE (Session 31 — ✅ COMPLETE)
- Backend: ✅ LIVE at https://plately-production.up.railway.app ({"status":"ok","recipes":94})
- Neon DB: ✅ Connected + seeded
- Landing page: ✅ Live at https://chishiyaj.github.io/plately
- GitHub secrets: ✅ All 7 set including PLATELY_API_URL=https://plately-production.up.railway.app
- cron-job.org: ✅ Pinging /api/health every 10 min
- Advisory lock / migration deadlock: ✅ Fixed on backend
- distribute.yml: ✅ FIXED — keystore cp'd to android/app/ so Gradle finds it (storeFile resolves relative to app subproject)
- ALLOWED_ORIGINS: ⬜ Still needs to be added in Railway Variables = https://plately-production.up.railway.app

## CURRENT STATE (Session 30 — ✅ COMPLETE)
- Flutter analyze: ✅ 0 issues (Session 30 verified)
- update_service.dart: ✅ NEW — semver comparison, 8s timeout, silent fail, reads version.json from GitHub raw URL
- home_screen.dart: ✅ _checkForUpdate() in initState, _buildUpdateBanner() shown when update available, "Later" dismisses session-only
- plately-landing/index.html: ✅ NEW — GitHub Pages landing page, dark teal, Nunito+DM Sans, hero+USP+mockups+steps+footer, scroll reveal
- .github/workflows/distribute.yml: ✅ NEW — auto build + Firebase App Distribution on every push to main
- FIREBASE_DIST.md: ✅ NEW — complete setup guide, secrets list, landing page deploy steps, version.json format

## CURRENT STATE (Session 29 — ✅ COMPLETE)
- database.py: ✅ ~100 recipes seeded (60 original + 40 new regional Filipino + budget Asian), cost_php in nutrition table for all new recipes
- recipe.dart: ✅ costPhp field — fromJson/toJson/copyWith
- recipe_card.dart: ✅ ₱ cost chip (yellow/orange) below protein badge when costPhp > 0
- recipe_detail_screen.dart: ✅ ₱ cost per serving row in nutrition card
- recipe_results_screen.dart: ✅ costPhp wired, search bar done S27
- favorites_screen.dart: ✅ costPhp wired to RecipeCard
- backend/routes/recipes.py: ✅ cost_php in browse + DB fallback queries, image_url in result dicts
- backend/routes/favorites.py: ✅ cost_php in SQL + nutrition response dict

## CURRENT STATE (Session 28 — ✅ COMPLETE)
- notification_service.dart: ✅ Full rewrite — 5 dynamic notifications
- home_screen.dart: ✅ schedulePersonalized() called after _loadPrefs()
- recipe_detail_screen.dart: ✅ notifyCookingDone() now passes cal, protein, userName named params

## CURRENT STATE (Session 27 — ✅ COMPLETE)
- offline_recipe_service.dart: ✅ NEW — sqflite cache
- recipe_results_screen.dart: ✅ offline banner + Retry, search bar
- recipe_detail_screen.dart: ✅ _isOffline flag, Offline chip badge, Ask AI FAB hidden when offline

## CURRENT STATE (Session 26 — ✅ COMPLETE)
- plately_share_card.dart: ✅ NEW
- recipe_detail_screen.dart: ✅ _showShareSheet() after _finishCooking()
- user_prefs_service.dart: ✅ hasSeenStreakMilestone + markStreakMilestoneSeen + saveLastCookedName
- home_screen.dart: ✅ _checkStreakMilestones() — milestone dialog at 3/7/14/30 days

## CURRENT STATE (Session 25 — ✅ COMPLETE)
- database.py: ✅ PG connection pooling — ThreadedConnectionPool(1,5)
- database.py: ✅ ai_recipe_cache table — both PG + SQLite schemas
- database.py: ✅ 60 recipes seeded with accurate dish-matched Unsplash images
- recipes.py: ✅ DB-backed AI recipe cache (survives redeployment)
- history_screen.dart: ✅ Cook Again — tapping entry navigates to RecipeResultsScreen
- key.properties: ✅ storeFile=upload-keystore.jks (correct, no path prefix)
- user_prefs_service.dart: ✅ incrementStreak() + getStreak() + isOnboardingDone()
- recipe_detail_screen.dart: ✅ incrementStreak() called in _finishCooking()
- home_screen.dart: ✅ streak pill shown when streak ≥ 2

---

## PRE-DEPLOY CHECKLIST

### Marco (backend):
- [x] Deploy backend to Railway ✅
- [x] Neon.tech DB connected ✅
- [x] cron-job.org pinging /api/health every 10 min ✅
- [ ] Set ALLOWED_ORIGINS in Railway Variables = https://plately-production.up.railway.app

### Marc (frontend):
- [x] Keystore generated at frontend/android/upload-keystore.jks ✅
- [x] GitHub secrets set ✅
- [x] distribute.yml fixed — keystore path bug resolved ✅
- [ ] Add permission_handler: ^11.3.1 to pubspec.yaml (needed for camera fix — Prompt A)
- [ ] Verify APK builds on next push to main
- [ ] Firebase App Distribution — add tester emails in Firebase Console

### Team smoke test (post-S32):
- [ ] Sign up with email → verify → log in
- [ ] Sign in with Google
- [ ] Camera viewfinder shows live feed (not blank)
- [ ] Dark mode toggle on profile → text visible in all screens
- [ ] Goals set in onboarding → reflected immediately in profile Edit Goals
- [ ] Type ingredients → AI recipes return (not empty)
- [ ] AI chat responds
- [ ] Home: tap past date pill → shows that day's macro history
- [ ] No emoji visible anywhere in the app
- [ ] History cards compact (not oversized)
- [ ] Nutrition card 2x2 grid in recipe detail

---

## BACKLOG (nice-to-have, post v1.1)
- [ ] Recipe rating / cook count (backend + UI)
- [ ] Custom recipe notes (per-user, stored in DB)
- [ ] Ingredient substitution AI ("I don't have X" in recipe detail)
- [ ] Shopping list → share as plain text (WhatsApp, SMS)
- [ ] Sentry error monitoring (free tier)
- [ ] ALLOWED_ORIGINS Railway env var (CORS hardening)

---

## STATUS KEY
- [x] = done and verified
- [~] = in progress / partially done
- [ ] = not started

---

## SESSION LOG

| Session | What Was Done | Key Files |
|---------|---------------|-----------|
| 1 | Google logo, history model, AI nav | home_screen, history_screen |
| 2 | Scan FAB, back button, lint | main_shell, recipe_detail_screen |
| 3 | flutter analyze → 0 issues | 5 screen files |
| 4 | Mifflin-St Jeor goals dialog | profile_screen |
| 5 | Gemma AI, ingredient matching, 3 new recipes | scan.py, database.py, chat.py |
| 6 | .md files rewrite | MEMORY.md, SKILLS.md, TASKS.md |
| 7 | Full source audit, .md corrected | MEMORY.md, SKILLS.md, TASKS.md |
| 8 | user_id isolation, baseUrl dart-define, Filipino filter, chat rate limit, KeepAlive, DEPLOY.md | api_service, recipes.py, chat.py, main.dart |
| 9 | widget_test fixed, profile stats, pantry rewrite, notifications, Railway deploy | multiple files |
| 10 | AI model fixes, pantry UI redesign, remove My Pantry from profile, V2 scrub, icon polish | chat.py, scan.py, pantry/home/profile screens |
| 11 | Macro calendar widget in home_screen | home_screen.dart |
| 12 | Dark mode Part 1: tokens + helpers, ThemeMode.system, 4 screens | app_theme, main, home, results, favorites, detail |
| 13 | Dark mode Part 2: remaining 5 screens | ai_chat, pantry, shopping, ingredient_entry, main_shell |
| 14 | Onboarding goals screen, empty states, scan SnackBar | onboarding_goals_screen, history, favorites, ingredient_entry |
| 15 | Backend validation, APK signing template | recipes.py, favorites.py, key.properties |
| 16 | App icon + native splash + Gradle Firebase + scan freeze fix | pubspec.yaml, mipmap-*/, build.gradle.kts |
| 17 | Offline banner + wake-up banner + recipe cache + offline state + RefreshIndicators | home_screen, recipe_results, history_screen, recipe.dart |
| 18 | profile_screen.dart full rebuild — Privacy Policy, Edit Goals, onboarding banner, version footer | profile_screen.dart |
| 19 | CachedNetworkImage, infinite scroll, gzip, dietary prefs fix | recipe_card, recipe_results, app.py, profile_screen |
| 20 | Full real-user audit + all fixes: macro logging, wakeup banner, Google login goals, onboarding, Filipino filter, PG PLACEHOLDER fixes, history calories/protein columns | recipe_detail, home, login, favorites, onboarding_goals, history.py, favorites.py, recipes.py, database.py |
| 21 | imageUrl field in Recipe model, getRecipes() timeout (30s), onboarding done flag | recipe.dart, api_service.dart, user_prefs_service.dart, onboarding_goals_screen.dart, main.dart |
| 22 | Scan empty state recovery UI, recipe detail shimmer skeleton, timer haptic | ingredient_entry_screen.dart, recipe_detail_screen.dart |
| 23 | didChangeDependencies macro ring refresh, Shopee clipboard fallback | home_screen.dart, shopping_list_screen.dart |
| 24 | 60 recipes with dish-matched images, DB-backed AI cache, streak system | database.py, recipes.py, user_prefs_service.dart, recipe_detail_screen.dart, home_screen.dart |
| 25 | PG connection pooling, Cook Again SnackBar, key.properties verified, final audit scores | database.py, history_screen.dart, TASKS.md |
| 26 | Viral share card, streak milestone popups (3/7/14/30 days), saveLastCookedName | plately_share_card.dart, recipe_detail_screen.dart, home_screen.dart, user_prefs_service.dart |
| 27 | Offline recipe browsing — sqflite cache service, offline banner, search bar, Offline chip badge | offline_recipe_service.dart, recipe_results_screen.dart, recipe_detail_screen.dart |
| 28 | Hyperpersonalized notifications — 5 dynamic notifs with gen-Z copy, schedulePersonalized() | notification_service.dart, home_screen.dart, recipe_detail_screen.dart |
| 29 | ~100 recipes (40 new regional Filipino + budget Asian), cost_php column, ₱ chips | database.py, recipe.dart, recipe_card.dart, recipe_detail_screen.dart, recipes.py, favorites.py |
| 30 | UpdateService, landing page, GitHub Actions CI/CD, FIREBASE_DIST.md | update_service.dart, home_screen.dart, plately-landing/index.html, distribute.yml, FIREBASE_DIST.md |
| 31 | GitHub Actions keystore path bug fixed (cp to android/app/), backend live on Railway, Neon DB connected, landing page live, cron-job.org set up, TASKS.md updated | .github/workflows/distribute.yml, TASKS.md |
| 32 | Full source audit — 6 fix sessions queued (E→A→B→C→D→F) | TASKS.md |
