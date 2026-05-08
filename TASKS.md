## CURRENT STATE (Session 30 — ✅ COMPLETE)
- Flutter analyze: ✅ 0 issues (Session 30 verified)
- update_service.dart: ✅ NEW — semver comparison, 8s timeout, silent fail, reads version.json from GitHub raw URL
- home_screen.dart: ✅ _checkForUpdate() in initState, _buildUpdateBanner() shown when update available, "Later" dismisses session-only
- plately-landing/index.html: ✅ NEW — GitHub Pages landing page, dark teal, Nunito+DM Sans, hero+USP+mockups+steps+footer, scroll reveal
- .github/workflows/distribute.yml: ✅ NEW — auto build + Firebase App Distribution on every push to main
- FIREBASE_DIST.md: ✅ NEW — complete setup guide, secrets list, landing page deploy steps, version.json format

## CURRENT STATE (Session 29 — ✅ COMPLETE)
- Flutter analyze: ✅ 0 issues (Session 29 verified)
- database.py: ✅ ~100 recipes seeded (60 original + 40 new regional Filipino + budget Asian), cost_php in nutrition table for all new recipes, duplicate recipes removed
- recipe.dart: ✅ costPhp field — fromJson/toJson/copyWith
- recipe_card.dart: ✅ ₱ cost chip (yellow/orange) below protein badge when costPhp > 0
- recipe_detail_screen.dart: ✅ ₱ cost per serving row in nutrition card
- recipe_results_screen.dart: ✅ costPhp wired, search bar already done S27
- favorites_screen.dart: ✅ costPhp wired to RecipeCard
- backend/routes/recipes.py: ✅ cost_php in browse + DB fallback queries, image_url in result dicts
- backend/routes/favorites.py: ✅ cost_php in SQL + nutrition response dict
- Flutter analyze: ✅ 0 issues (Session 28 verified)
- notification_service.dart: ✅ Full rewrite — 5 dynamic notifications: Morning Fuel Check (8AM), Midday Macro Check (1PM, shows remaining protein), Streak Protection (6:30PM, streak-aware copy), Weekend Inspo (Saturday 11AM, references last cooked dish), Cook Done (one-shot with cal/protein/name)
- notification_service.dart: ✅ schedulePersonalized() — cancel + reschedule on every app open, gen-Z copy, Random seeded by day-of-year for consistency
- notification_service.dart: ✅ _scheduleWeeklyOnSaturday() for weekend notif using DateTimeComponents.dayOfWeekAndTime
- home_screen.dart: ✅ schedulePersonalized() called after _loadPrefs() with live name/proteinGoal/proteinConsumed/streak/lastCookedName
- recipe_detail_screen.dart: ✅ notifyCookingDone() now passes cal, protein, userName named params
- Flutter analyze: ✅ 0 issues (Session 27 verified)
- offline_recipe_service.dart: ✅ NEW — sqflite cache (cacheRecipes, getCachedRecipes, getCachedRecipesByTag, hasCache, clearCache)
- recipe_results_screen.dart: ✅ caches on successful browse load, loads from sqflite on API fail, offline yellow banner + Retry, search bar (client-side filter, result count, clear button, no-results state)
- recipe_detail_screen.dart: ✅ _isOffline flag, Offline chip badge in hero, Ask AI FAB hidden when offline
- Flutter analyze: ✅ 0 issues (Session 26 verified)
- plately_share_card.dart: ✅ NEW — standalone share card widget (dark teal, macros, streak badge)
- recipe_detail_screen.dart: ✅ _showShareSheet() called after _finishCooking(), _ShareBottomSheet with preview + Share/Skip buttons
- user_prefs_service.dart: ✅ hasSeenStreakMilestone(n) + markStreakMilestoneSeen(n) + saveLastCookedName/getLastCookedName
- home_screen.dart: ✅ _checkStreakMilestones() — milestone dialog at 3/7/14/30 days with emoji + share CTA
- Flutter analyze: ✅ 0 issues (Session 25 verified)
- database.py: ✅ PG connection pooling — ThreadedConnectionPool(1,5), proper getconn/putconn in query/execute/executemany/_create_tables
- database.py: ✅ ai_recipe_cache table — both PG + SQLite schemas
- database.py: ✅ 60 recipes seeded with accurate dish-matched Unsplash images
- recipes.py: ✅ DB-backed AI recipe cache (survives redeployment)
- history_screen.dart: ✅ Cook Again — tapping entry navigates to RecipeResultsScreen; SnackBar if no ingredients
- key.properties: ✅ storeFile=upload-keystore.jks (correct, no path prefix)
- user_prefs_service.dart: ✅ incrementStreak() + getStreak() + isOnboardingDone()
- recipe_detail_screen.dart: ✅ incrementStreak() called in _finishCooking()
- home_screen.dart: ✅ 🔥 streak pill shown when streak ≥ 2
- APK build: ⚠️ keystore not generated yet — Marc must run keytool first (see PRE-DEPLOY CHECKLIST)

### FINAL AUDIT SCORES (self-assessed)
- Code quality: 98/100
- Backend reliability: 99/100
- UX completeness: 97/100
- Security: 91/100
- Deploy readiness: 85/100 (APK blocked on keystore generation + Marco's infra tasks)
- Popularity potential: 95/100
- Flutter analyze: ✅ 0 issues (Session 23 final verified)
- history.py: ✅ calories_logged + protein_logged accepted and stored in DB
- database.py: ✅ history table schema updated — both PostgreSQL + SQLite
- database.py: ✅ ALTER TABLE IF NOT EXISTS migration guard for existing Render DB
- history_screen.dart: ✅ 7-day chart reads real logged calories/protein
- recipe_detail_screen.dart: ✅ _finishCooking() logs calories + protein to UserPrefsService + API
- recipe_detail_screen.dart: ✅ "Finish Cooking" on BOTH tabs (Ingredients + Steps)
- recipe_detail_screen.dart: ✅ SnackBar shows "+X kcal · +Xg protein logged!" after cooking
- recipe_detail_screen.dart: ✅ Loading spinner on Finish Cooking button (prevents double-tap)
- recipe_detail_screen.dart: ✅ Shimmer skeleton shown while fetching recipe detail (browse-mode)
- recipe_detail_screen.dart: ✅ _fetchedRecipe / _loadingDetail state — fetches /api/recipe/<id> when ingredients empty
- home_screen.dart: ✅ Wakeup banner stays until server actually responds (not timer-based)
- home_screen.dart: ✅ Banner text updated to "30–60s"
- home_screen.dart: ✅ didChangeDependencies calls _loadPrefs() — macro rings update on nav back
- Macro rings: ✅ Now update correctly — calConsumed/proteinConsumed written on Finish Cooking
- login_screen.dart: ✅ Google login uses shared _navigateAfterLogin() — goals check applies to both auth methods
- onboarding_goals_screen.dart: ✅ skip saves 2200 — consistent with main.dart signal
- favorites_screen.dart: ✅ Filipino filter chip present
- favorites_screen.dart: ✅ Nutrition chips (calories/protein) already populated via favorites.py JOIN
- favorites.py: ✅ Nutrition JOIN already present — calories/protein/carbs/fat returned
- recipes.py: ✅ PLACEHOLDER used throughout (PostgreSQL compat)
- favorites.py: ✅ PLACEHOLDER used throughout
- history.py: ✅ PLACEHOLDER used throughout, dual-mode interval syntax
- ingredient_entry_screen.dart: ✅ _scanFailed state — inline recovery UI (Try Again + Type Instead) when scan returns 0 ingredients
- shopping_list_screen.dart: ✅ Shopee canLaunchUrl check + clipboard fallback with SnackBar
- Timer haptic + notification: ✅ Already wired in Session 20 (_startTimer fires HapticFeedback.heavyImpact + NotificationService.notifyCookingDone)

---

## SESSIONS 21–25 — AUDIT FIX PLAN (100/100 across all six dimensions)
> Audit after Session 20: Code 94 · Backend 88 · UX 71 · Security 91 · Deploy 65 · Popularity 82
> Target: all six → 100 by Session 25.
> HOW TO USE: Open a NEW Claude.ai chat. Paste MEMORY.md → SKILLS.md → TASKS.md → then the SESSION PROMPT block for that session.

---

### SESSION 21 — Critical Bug Fixes: imageUrl + timeout + onboarding flag
**Status:** ⬜ NOT STARTED
**Audit fixes:** CRIT 1 (imageUrl), CRIT 2 (getRecipes timeout), CRIT 5 (onboarding skip signal)
**Score targets:** Code 94→97 · Backend 88→93 · Deploy 65→72

#### ═══ SESSION 21 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 21 — Critical Bug Fixes.
Targeting 100/100 on a 6-dimension audit. Fix every item below exactly as specified.
Rules: full files only (no // ...rest stays the same), no hex in screens, DM Sans body text, flutter analyze 0 issues at end.

FIX 1 — CRIT 1: imageUrl missing from Recipe model
Problem: Backend sends image_url but Recipe.fromJson() silently drops it. Every card shows fallback.

File: frontend/lib/models/recipe.dart
  1. Add field: final String imageUrl;
  2. Add to constructor (with default '').
  3. fromJson(): imageUrl: json['image_url'] as String? ?? '',
  4. toJson(): 'image_url': imageUrl,
  5. copyWith() if it exists: imageUrl: imageUrl ?? this.imageUrl,
Output: complete recipe.dart. No partial.

File: frontend/lib/widgets/recipe_card.dart
  - imageUrl.isNotEmpty → CachedNetworkImage(imageUrl: recipe.imageUrl)
  - imageUrl.isEmpty → keep existing keyword-based Unsplash fallback URL
Output: complete recipe_card.dart. No partial.

FIX 2 — CRIT 2: getRecipes() has no timeout
Problem: HTTP POST to /api/recipes has no .timeout(). On 50s Render cold start, spinner never resolves.

File: frontend/lib/services/api_service.dart
  - Add .timeout(const Duration(seconds: 30)) to the getRecipes() http.post() call.
  - In catch block: add TimeoutException alongside SocketException — both return null.
  - Ensure import 'dart:async'; is present.
  - Matches pattern already used by scanImage() (30s) and sendChat() (20s).
Output: complete api_service.dart. No partial.

FIX 3 — CRIT 5: Onboarding skip signal broken
Problem: main.dart uses calGoal == 2200 sentinel. Real user wanting 2200 kcal loops in onboarding forever.

File: frontend/lib/services/user_prefs_service.dart
Add alongside existing methods:
  static const _kOnboardingDone = 'onboarding_done';
  Future<void> setOnboardingDone() async => (await _prefs()).setBool(_kOnboardingDone, true);
  Future<bool> isOnboardingDone() async => (await _prefs()).getBool(_kOnboardingDone) ?? false;
Output: complete user_prefs_service.dart. No partial.

File: frontend/lib/screens/onboarding_goals_screen.dart
  - Call await UserPrefsService().setOnboardingDone(); in BOTH the skip AND save handlers, before navigation.
Output: complete onboarding_goals_screen.dart. No partial.

File: frontend/lib/main.dart
  - Replace calGoal == 2200 check with: final done = await UserPrefsService().isOnboardingDone();
  - If done is false, push OnboardingGoalsScreen. If true, proceed to MainShell.
  - Remove ALL references to the calGoal == 2200 sentinel.
Output: complete main.dart. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 21 COMPLETE, add to SESSION LOG, update CURRENT STATE.

#### Marco's infra tasks — do IN PARALLEL with Session 21 (no code):

CRIT 3 — Neon.tech DB migration (prevents DB deletion in 90 days):
  1. neon.tech → Sign up free → Create project → Copy postgres:// connection string.
  2. pg_dump "RENDER_DATABASE_URL" | psql "NEON_DATABASE_URL"
  3. Render → Environment → DATABASE_URL → paste Neon URL → Save → Manual redeploy.
  4. GET https://plately-r1xp.onrender.com/api/health → confirm 200 + recipe_count > 0.
  5. Test favorites + history still work.

CRIT 4 — cron-job.org (eliminates 50s cold starts):
  1. cron-job.org → Sign up → Create Cronjob.
  2. URL: https://plately-r1xp.onrender.com/api/health — Schedule: every 10 min.
  3. Enable → Save → check Execution log after 10 min → confirm 200.

---

### SESSION 22 — UX Polish Part 1: Haptic Timers + Scan Recovery + Detail Skeleton
**Status:** ✅ COMPLETE
**Audit fixes:** UX 1 (recipe detail skeleton), UX 2 (scan empty state), UX 6 (timer haptic + notification)
**Score targets:** UX 71→85 · Code 97→98

#### ═══ SESSION 22 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 22 — UX Polish Part 1.
Targeting 100/100 on a 6-dimension audit. Fix every item below exactly as specified.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.

FIX 1 — UX 6: Step timers have no haptic or notification on completion
Problem: Timer hits 0 in recipe_detail_screen but user gets zero feedback. Useless in a real kitchen.

File: frontend/lib/screens/recipe_detail_screen.dart
Find _timerTick() or wherever timer countdown reaches 0.
When timer value transitions to 0, do BOTH:
  1. HapticFeedback.heavyImpact();
     Check existing imports — add import 'package:flutter/services.dart'; if missing.
  2. Show a local notification via NotificationService:
     Instantiate NotificationService once as a field in the State class (not inside tick function).
     Call: notifService.showCookingDoneNotification();
     If showCookingDoneNotification() does not exist in NotificationService, add it:
       Future<void> showCookingDoneNotification() async {
         await flutterLocalNotificationsPlugin.show(
           99,
           'Timer Done!',
           'Your cooking step timer finished — check the recipe!',
           const NotificationDetails(
             android: AndroidNotificationDetails(
               'plately_cooking', 'Cooking',
               importance: Importance.high, priority: Priority.high,
             ),
           ),
         );
       }
     Output notification_service.dart if you add to it — complete file, no partial.
Output: complete recipe_detail_screen.dart. No partial.

FIX 2 — UX 2: Camera scan returns 0 ingredients — no recovery UX
Problem: When AI scan returns empty list, chip area is blank. Users think the feature is broken.

File: frontend/lib/screens/ingredient_entry_screen.dart
Add a bool _scanFailed = false; state variable.
When scan returns an empty ingredient list: setState(() => _scanFailed = true);
When scan returns non-empty results: setState(() => _scanFailed = false);
When a new scan is triggered: reset _scanFailed = false;

In build, in the scan-mode result area — if _scanFailed is true, show instead of the chip area:
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(LucideIcons.cameraOff, size: 40, color: AppTheme.mutedText),
      SizedBox(height: 12),
      Text('Nothing detected', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      SizedBox(height: 4),
      Text('Try better lighting or a closer angle',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.mutedText),
        textAlign: TextAlign.center),
      SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _clearAndRetry, child: Text('Try Again'))),
        SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () => _tabController.animateTo(1),
          child: Text('Type Instead'))),
      ]),
    ],
  )
_clearAndRetry: resets captured image, sets _scanFailed = false, re-opens camera viewfinder.
_tabController.animateTo(1): switches to type-mode tab (index 1).
Output: complete ingredient_entry_screen.dart. No partial.

FIX 3 — UX 1: No loading skeleton on recipe detail screen
Problem: Browse-mode card tap triggers a network call but screen shows blank during load.

File: frontend/lib/screens/recipe_detail_screen.dart
Add bool _loadingDetail = true; state variable (set false after full recipe data loads).
While _loadingDetail == true, show a shimmer skeleton (shimmer package already in pubspec):
  Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 220, width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        SizedBox(height: 16),
        Container(height: 24, width: 200, color: Colors.white),
        SizedBox(height: 8),
        Container(height: 16, width: 140, color: Colors.white),
        SizedBox(height: 16),
        Container(height: 80, width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
        SizedBox(height: 16),
        ...List.generate(4, (_) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Container(height: 20, width: double.infinity, color: Colors.white),
        )),
      ]),
    ),
  )
Once data loads, set _loadingDetail = false.
Wrap real content in AnimatedSwitcher(duration: Duration(milliseconds: 200)) to fade in.
If the recipe already comes fully loaded (from AI results screen), skip loading state — only show skeleton when fetching from /api/recipe/<id>.
Output: complete recipe_detail_screen.dart. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 22 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 23 — UX Polish Part 2: Favorites Chips + Macro Rings + Shopee Fallback
**Status:** ✅ COMPLETE
**Audit fixes:** UX 3 (nutrition chips on favorites cards), UX 4 (macro rings stale), UX 5 (Shopee fallback)
**Score targets:** UX 85→96 · Backend 93→96

#### ═══ SESSION 23 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 23 — UX Polish Part 2.
Targeting 100/100 on a 6-dimension audit. Fix every item below exactly as specified.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.

FIX 1 — UX 3: Favorites cards missing calorie + protein chips
Problem: Recipe results cards show calorie + protein badges. Favorites cards do not. Inconsistent.

STEP A — Backend:
File: backend/routes/favorites.py
In the GET /api/favorites endpoint SQL query, add a JOIN to the nutrition table:
  SELECT r.id, r.name, r.cook_time, r.difficulty, r.tags, r.image_url,
         n.calories, n.protein, n.carbs, n.fat
  FROM favorites f
  JOIN recipes r ON r.id = f.recipe_id
  LEFT JOIN nutrition n ON n.recipe_id = r.id
  WHERE f.user_id = {ph}
Include calories, protein, carbs, fat in the JSON response for each recipe object.
Use PLACEHOLDER variable (ph) throughout — never hardcoded ? or %s.
Output: complete favorites.py. No partial.

STEP B — Flutter:
File: frontend/lib/screens/favorites_screen.dart
When building Recipe objects from favorites API response, parse calories and protein:
  calories: json['calories'] as int? ?? 0,
  protein: json['protein'] as int? ?? 0,
Ensure RecipeCard receives a Recipe with populated calories + protein so its badge logic shows them.
Output: complete favorites_screen.dart. No partial.

FIX 2 — UX 4: Macro rings don't update when navigating back to Home
Problem: calConsumed + proteinConsumed load in initState once. After Finish Cooking, navigating back shows stale values.

File: frontend/lib/screens/home_screen.dart
Add to _HomeScreenState:
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs();
  }
This fires on initial mount AND whenever the user returns to this screen via Navigator.pop.
If _loadPrefs() is already called in initState, keep both — they serve different lifecycles (init for first load, didChangeDependencies for return navigation).
Ensure _loadPrefs() checks if mounted before calling setState to avoid errors.
Output: complete home_screen.dart. No partial.

FIX 3 — UX 5: Shopee deep-link fails silently
Problem: url_launcher opens shopee.ph but does nothing if Shopee is not installed. No fallback.

File: frontend/lib/screens/shopping_list_screen.dart
Before launching Shopee URL:
  final canLaunch = await canLaunchUrl(Uri.parse(shopeeUrl));
If canLaunch is false:
  1. Build plain-text shopping list string (one ingredient + quantity per line).
  2. await Clipboard.setData(ClipboardData(text: shoppingListText));
  3. ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Shopee not available — shopping list copied to clipboard!')),
     );
If canLaunch is true: launch as before.
Capture ScaffoldMessenger BEFORE any await to avoid context-across-async-gap lint warning:
  final messenger = ScaffoldMessenger.of(context);
  // ... then use messenger.showSnackBar(...)
Add import 'package:flutter/services.dart'; if not present (for Clipboard).
Output: complete shopping_list_screen.dart. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 23 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 24 — Content Depth + Retention: 60 Recipes + DB Cache + Streak System
**Status:** ⬜ NOT STARTED
**Audit fixes:** PERF 1 (34 recipes), PERF 2 (AI cache resets on redeploy), Social/retention 30→70
**Score targets:** Popularity 82→95 · Backend 96→99

#### ═══ SESSION 24 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 24 — Content Depth + Retention.
Targeting 100/100 on a 6-dimension audit. Fix every item below exactly as specified.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.

FIX 1 — PERF 1: Only 34 seeded recipes — users exhaust content in one session
Target: 60+ seeded recipes.

File: backend/database.py
Add 26+ new recipes following the EXACT same INSERT pattern as existing seeds.
Do NOT modify or remove any existing recipes — only ADD.
Categories to add:
  5 more Filipino (tag 'Filipino'): Pakbet, Dinuguan, Laing, Kaldereta, Pinakbet Ilocano
  5 more Asian (tag 'Asian'): Korean Bibimbap, Thai Basil Chicken, Japanese Gyudon, Mapo Tofu, Pad Thai
  4 more Italian (tag 'Italian'): Cacio e Pepe, Pasta Aglio e Olio, Bruschetta, Risotto Bianco
  4 more Vegetarian (tag 'Vegetarian'): Shakshuka, Red Lentil Soup, Caprese Salad, Veggie Buddha Bowl
  4 more High-Protein (tag 'High-Protein'): Turkey Meatballs, Tuna Salad Bowl, Greek Yogurt Parfait, Chicken Caesar
  4 more Low-Cal (tag 'Low-Cal'): Zucchini Noodles, Cauliflower Fried Rice, Miso Soup, Cucumber Salad
Each new recipe requires:
  name, cook_time (e.g. '20 mins'), difficulty ('Easy'/'Medium'/'Hard')
  instructions: JSON array of step strings '["Step 1.", "Step 2."]'
  tags: comma-separated from valid set: Asian, Italian, Vegetarian, Low-Cal, High-Protein, Filipino
  image_url: real Unsplash URL (https://images.unsplash.com/photo-XXXXXXXX?w=400)
  nutrition row: calories, protein, carbs, fat (realistic ints)
  At least 4 recipe_ingredients rows
Add any missing ingredients to the ingredients table first.
Update the seed count comment in database.py from 34 to 60+.
Also update MEMORY.md: recipe count 34 → 60, update the recipe list table.
Output: complete database.py. No partial. Also output updated MEMORY.md.

FIX 2 — PERF 2: AI recipe cache resets on every Render redeploy
Problem: _ai_cache = {} is in-memory. Every deployment wipes it. Users wait 35s again post-deploy.

File: backend/database.py
In init_db(), add after existing CREATE TABLE statements:
  CREATE TABLE IF NOT EXISTS ai_recipe_cache (
      cache_key TEXT PRIMARY KEY,
      recipes_json TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
This change goes in the same database.py modified in FIX 1 above — single file output.

File: backend/routes/recipes.py
Replace the _ai_cache dict with DB-backed cache:
  On request with ingredients, generate cache_key (same fingerprint as before).
  Check DB cache:
    PG:     SELECT recipes_json FROM ai_recipe_cache WHERE cache_key = {ph} AND created_at > NOW() - INTERVAL '1 hour'
    SQLite: SELECT recipes_json FROM ai_recipe_cache WHERE cache_key = {ph} AND datetime(created_at) > datetime('now', '-1 hour')
    Use USE_PG flag to select correct SQL.
  Cache hit: return json.loads(recipes_json) immediately.
  Cache miss: call AI, then upsert result:
    PG:     INSERT INTO ai_recipe_cache (cache_key, recipes_json) VALUES ({ph},{ph}) ON CONFLICT (cache_key) DO UPDATE SET recipes_json = EXCLUDED.recipes_json, created_at = CURRENT_TIMESTAMP
    SQLite: INSERT OR REPLACE INTO ai_recipe_cache (cache_key, recipes_json, created_at) VALUES ({ph},{ph}, datetime('now'))
  Remove the _ai_cache dict and all TTL logic — DB handles expiry via the WHERE clause.
  Existing imports from database module should include USE_PG — add if missing.
Output: complete recipes.py. No partial.

FIX 3 — Streak system
File: frontend/lib/services/user_prefs_service.dart
Add streak tracking alongside existing prefs methods:
  static const _kStreak = 'cook_streak';
  static const _kLastCookDate = 'last_cook_date';

  Future<int> getStreak() async => (await _prefs()).getInt(_kStreak) ?? 0;

  Future<void> incrementStreak() async {
    final prefs = await _prefs();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastCook = prefs.getString(_kLastCookDate) ?? '';
    if (lastCook == today) return; // already cooked today
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final current = prefs.getInt(_kStreak) ?? 0;
    final newStreak = (lastCook == yesterday) ? current + 1 : 1;
    await prefs.setInt(_kStreak, newStreak);
    await prefs.setString(_kLastCookDate, today);
  }
Output: complete user_prefs_service.dart. No partial.

File: frontend/lib/screens/recipe_detail_screen.dart
In _finishCooking(), after existing macro logging calls, add:
  await UserPrefsService().incrementStreak();
Output: complete recipe_detail_screen.dart (start from Session 22 version). No partial.

File: frontend/lib/screens/home_screen.dart
In _loadPrefs(), add: final streak = await UserPrefsService().getStreak();
Store as int _streak = 0; state variable.
In build, in the hero greeting area (below greeting, above quick actions), add:
  if (_streak >= 2) ...[
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text('$_streak day streak',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.yellow, fontWeight: FontWeight.w700)),
      ]),
    ),
  ]
Show nothing if streak <= 1 (don't clutter for new/lapsed users).
Output: complete home_screen.dart (start from Session 23 version). No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update MEMORY.md: recipe count 34 → 60+, add ai_recipe_cache to DB tables list.
Update TASKS.md: mark SESSION 24 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 25 — DB Connection Pooling + Cook Again + Release Build + 100/100 Verification
**Status:** ⬜ NOT STARTED
**Audit fixes:** PERF 3 (DB pooling), Deploy 65→100, final smoke test + APK + git tag
**Score targets:** Deploy→100 · Backend→100 · Code→100 · all six → 100

#### ═══ SESSION 25 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 25 — DB Pooling + Cook Again + Release Build. FINAL SESSION.
Targeting 100/100 on all six audit dimensions. Fix every item below exactly as specified.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.

FIX 1 — PERF 3: No DB connection pooling
Problem: threading.local() in database.py creates one PG connection per thread. Exhausts free-tier PG connection limit under multi-user load.

File: backend/database.py (start from Session 24 version)
Only the PostgreSQL branch changes — SQLite is unchanged.
Add to imports: from psycopg2 import pool as pg_pool
Add global pool:
  _pg_pool = None

  def _get_pg_pool():
      global _pg_pool
      if _pg_pool is None:
          _pg_pool = pg_pool.ThreadedConnectionPool(1, 5, os.getenv('DATABASE_URL'))
      return _pg_pool

Update get_db() PG branch to use pool (keep context manager pattern):
  if USE_PG:
      conn = _get_pg_pool().getconn()
      try:
          yield conn
          conn.commit()
      except Exception:
          conn.rollback()
          raise
      finally:
          _get_pg_pool().putconn(conn)
Remove the threading.local() PG connection variables entirely.
SQLite branch: unchanged.
Output: complete database.py. No partial.

FIX 2 — Cook Again from history
Problem: History entries list recipe names but are not tappable. Users cannot re-cook a previous recipe.

File: frontend/lib/screens/history_screen.dart
Make each history entry card tappable (wrap with GestureDetector or InkWell).
On tap: if the entry has a non-empty recipe_name, navigate to RecipeResultsScreen with that recipe name:
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => RecipeResultsScreen(
      ingredients: [entry.recipeName],
      userPrefs: {},
    ),
  ));
  Adjust constructor args to match the actual RecipeResultsScreen constructor — read it first.
If recipe name is empty or entry represents a browse-only session (no specific recipe cooked):
  Show SnackBar: 'No specific recipe recorded for this session.'
Output: complete history_screen.dart. No partial.

FIX 3 — key.properties storeFile path
File: frontend/android/key.properties
Read the file first. Ensure the storeFile line reads exactly:
  storeFile=upload-keystore.jks
No prefix (no ../ and no absolute path). Gradle resolves it relative to the android/ folder.
Only change this line if it differs. Output full key.properties.

FINAL VERIFICATION CHECKLIST:
Step 1: Run flutter analyze — must be 0 issues. Paste exact output.
Step 2: Verify these files were updated across sessions 21–25:
  frontend/lib/models/recipe.dart — imageUrl field added
  frontend/lib/services/api_service.dart — getRecipes() timeout
  frontend/lib/services/user_prefs_service.dart — onboarding flag + streak
  frontend/lib/screens/onboarding_goals_screen.dart — setOnboardingDone on skip+save
  frontend/lib/main.dart — isOnboardingDone() check
  frontend/lib/screens/recipe_detail_screen.dart — skeleton, haptic timer, streak increment
  frontend/lib/screens/ingredient_entry_screen.dart — scan empty state
  frontend/lib/screens/home_screen.dart — didChangeDependencies, streak badge
  frontend/lib/screens/favorites_screen.dart — nutrition chips
  frontend/lib/screens/shopping_list_screen.dart — Shopee clipboard fallback
  frontend/lib/screens/history_screen.dart — tappable Cook Again
  backend/routes/favorites.py — nutrition JOIN
  backend/routes/recipes.py — DB-backed cache
  backend/database.py — 60 recipes, ai_recipe_cache table, PG pool
Step 3: Build release APK:
  flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-r1xp.onrender.com
Step 4: Confirm APK at: build/app/outputs/flutter-apk/app-release.apk
Step 5: Record final self-assessed audit scores in TASKS.md:
  Code quality: _/100
  Backend reliability: _/100
  UX completeness: _/100
  Security: _/100
  Deploy readiness: _/100
  Popularity potential: _/100
Step 6: Update TASKS.md — mark SESSION 25 COMPLETE, add to SESSION LOG.
Step 7: git tag v1.1.0 && git push --tags

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 25 COMPLETE, final scores, update CURRENT STATE.

---

## PRE-DEPLOY CHECKLIST (Marc + Marco — before distributing APK)

### Marco (backend):
- [ ] Push backend to GitHub (Render auto-deploys)
- [ ] Neon.tech DB migrated (see Session 21 infra checklist above)
- [ ] cron-job.org pinging /api/health every 10 min (see Session 21 infra checklist)
- [ ] Render env vars set: FLASK_ENV=production, SECRET_KEY, OPENROUTER_API_KEY, DATABASE_URL

### Marc (frontend):
- [ ] Generate keystore (run ONCE in frontend/android/ folder):
  keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias plately
  Use password: Marc.1234567890 (already set in key.properties)
- [ ] Confirm upload-keystore.jks at frontend/android/upload-keystore.jks
- [ ] Build release APK:
  flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-r1xp.onrender.com
- [ ] APK at: build/app/outputs/flutter-apk/app-release.apk
- [ ] Upload to Firebase App Distribution

### Team smoke test:
- [ ] Sign up with email → verify → log in
- [ ] Sign in with Google
- [ ] Set goals in onboarding → skip → confirm no infinite loop
- [ ] Browse recipes → recipe images display (not all fallback)
- [ ] Scan ingredients with camera → test empty scan → recovery UI appears
- [ ] Type ingredients → get AI recipes
- [ ] Open recipe → view ingredients + steps
- [ ] Start a step timer → when it hits 0, confirm haptic + notification fires
- [ ] Finish Cooking → macro snackbar appears → streak increments
- [ ] Navigate back to Home → macro rings show updated values immediately
- [ ] Check favorites → nutrition chips visible on cards
- [ ] Shopping list → tap Shopee button without Shopee → list copied to clipboard
- [ ] History screen → tap an entry → navigates to Cook Again
- [ ] Verify 60 recipes load in browse mode

---

## BACKLOG (nice-to-have, post v1.1)
- [ ] Recipe rating / cook count (backend + UI)
- [ ] Custom recipe notes (per-user, stored in DB)
- [ ] Ingredient substitution AI ("I don't have X" in recipe detail)
- [ ] Shopping list → share as plain text (WhatsApp, SMS)
- [ ] Push notification dynamic scheduling (based on actual cook times in history)
- [ ] Sentry error monitoring (free tier)

---

## SESSIONS 26–30 — GROWTH ARC (make it actually blow up)
> Goal: turn a great capstone into something people actually open every day and share with their friends.
> No paid APIs. No Play Store fee. All free-tier.
> HOW TO USE: Open a NEW Claude.ai chat. Paste MEMORY.md → SKILLS.md → TASKS.md → then the SESSION PROMPT block for that session.

---

### SESSION 26 — Viral Share Card + Streak Milestones
**Status:** ✅ COMPLETE
**Goal:** Every time someone finishes cooking, they get a fire share card they WANT to post. Free marketing.
**Packages needed:** screenshot + share_plus (both already in pubspec ✅)

#### ═══ SESSION 26 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 26 — Viral Share Card + Streak Milestones.
Goal: make Plately spread itself. Every finish-cooking moment becomes a shareable flex.
Rules: full files only, no hex in screens, no withOpacity, flutter analyze 0 issues at end.

FIX 1 — Post-cook Share Card
When _finishCooking() completes in recipe_detail_screen.dart, AFTER the SnackBar, show a bottom sheet with a share card widget.

The share card (a self-contained Widget called PlatelyShareCard) must look CLEAN and GEN-Z:
- Dark background using AppTheme.primaryDark
- Plately logo top-left (use PlatelyLogoTheme.onDark)
- Big dish name in Nunito bold white
- Macro pills: calories and protein side by side (AppTheme.green bg)
- Streak badge if streak >= 2: "🔥 X day streak" in AppTheme.yellow
- Bottom text: "track yours → plately.app" in mutedText small
- Rounded corners, looks like an Instagram story card (ratio ~9:16 portrait, width 280)

Capture it using the screenshot package (ScreenshotController), convert to image bytes.
Show a bottom sheet with:
  - Preview of the card
  - "Share" button → Share.shareXFiles([XFile.fromData(bytes)], text: 'Just cooked [dish] 🔥 +[cal]kcal +[protein]g protein. Tracking macros before I cook, not after. #Plately #NoCap')
  - "Skip" text button to dismiss

File: frontend/lib/widgets/plately_share_card.dart — new file, the card widget
File: frontend/lib/screens/recipe_detail_screen.dart — add share sheet trigger after _finishCooking()
Output: both files complete. No partial.

FIX 2 — Streak Milestone Popups
In home_screen.dart, after _loadPrefs(), check if streak is exactly 3, 7, 14, 30.
If it matches a milestone AND the user hasn't seen that milestone popup yet (store flag in UserPrefsService as 'streak_milestone_X'):
Show a full-screen overlay dialog (not just a SnackBar) with:
  - Big emoji: 3=🔥, 7=💪, 14=👑, 30=🐐
  - Title: 3="You're on a hot streak fr", 7="Week-long grind, no cap", 14="Two weeks of eating different", 30="GOAT behavior, lowkey impressive"
  - Subtitle: show streak count + "days cooking with Plately"
  - "Share this W" button → triggers same share card flow (ShareCard.showMilestone())
  - "Keep cooking" dismiss button

File: frontend/lib/services/user_prefs_service.dart — add hasSeenStreakMilestone(int n) + markStreakMilestoneSeen(int n)
File: frontend/lib/screens/home_screen.dart — milestone check in didChangeDependencies after _loadPrefs()
Output: both files complete. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 26 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 27 — Offline Recipe Browsing
**Status:** ✅ COMPLETE
**Goal:** Students cook in dorms with trash WiFi. App must work fully offline for browsing.
**Packages needed:** sqflite + shared_preferences (both already in pubspec ✅)

#### ═══ SESSION 27 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 27 — Offline Recipe Browsing.
Goal: browse all 60 recipes with zero connection. AI features degrade gracefully, not crash.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.

FIX 1 — Local Recipe Cache (sqflite)
File: frontend/lib/services/offline_recipe_service.dart — NEW FILE

Create OfflineRecipeService with:
  - initDb(): opens sqflite DB at 'plately_offline.db', creates table:
      CREATE TABLE IF NOT EXISTS cached_recipes (
        id INTEGER PRIMARY KEY, name TEXT, cook_time TEXT, difficulty TEXT,
        instructions TEXT, tags TEXT, image_url TEXT,
        calories INTEGER, protein INTEGER, carbs INTEGER, fat INTEGER
      )
  - cacheRecipes(List<Recipe> recipes): INSERT OR REPLACE all into sqflite
  - getCachedRecipes(): SELECT all, return List<Recipe>
  - getCachedRecipesByTag(String tag): filter by tags LIKE '%tag%'
  - clearCache(): DELETE FROM cached_recipes

File: frontend/lib/screens/recipe_results_screen.dart
  - On successful API load (browse mode, empty ingredients), call OfflineRecipeService().cacheRecipes(recipes)
  - On API failure (SocketException or TimeoutException), call OfflineRecipeService().getCachedRecipes()
  - If serving from cache: show a slim banner at top:
      Container with AppTheme.yellow bg, text: "Offline mode — showing saved recipes", icon: LucideIcons.wifiOff
  - If cache is also empty: show existing empty state with message "Connect once to load recipes"

Output: complete offline_recipe_service.dart + complete recipe_results_screen.dart. No partial.

FIX 2 — Offline Recipe Detail
File: frontend/lib/screens/recipe_detail_screen.dart
  - When fetching /api/recipe/<id> fails (browse mode), check if the recipe data was passed in full from RecipeResultsScreen
  - If recipe came from offline cache, it already has instructions/nutrition — skip the API fetch entirely
  - Show "Offline" chip badge (AppTheme.yellow, LucideIcons.wifiOff, small) in the app bar when in offline mode
  - "Ask AI" FAB should be hidden when offline (AI chat requires connection)

Output: complete recipe_detail_screen.dart. No partial.

FIX 3 — Offline Banner in Home
File: frontend/lib/screens/home_screen.dart
  - Existing offline/wakeup banner logic is already present — verify it shows correctly when offline
  - Add: if offline AND cache exists → show "Browsing saved recipes" pill instead of "Server waking up" banner
  - Use connectivity_plus package check OR catch SocketException from KeepAliveService

Note: if connectivity_plus is not in pubspec.yaml, add it. Output pubspec.yaml if changed.
Output: complete home_screen.dart. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 27 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 28 — Hyperpersonalized Push Notifications
**Status:** ✅ COMPLETE
**Goal:** Notifs that slap. Not "don't forget to log!" — actual personalized, funny, gen-z energy messages based on the user's real data.
**Packages needed:** flutter_local_notifications + timezone (both already in pubspec ✅)

#### ═══ SESSION 28 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 28 — Hyperpersonalized Push Notifications.
Goal: notifications so good and specific that users actually look forward to them.
Rules: full files only, no hex in screens, flutter analyze 0 issues at end.
Tone for ALL notification copy: gen-z, mog energy, cooking-as-self-improvement. No cringe corporate wellness speak.

FIX 1 — Rewrite NotificationService with dynamic, data-driven messages
File: frontend/lib/services/notification_service.dart

Replace the 3 static scheduled notifications with these 5 dynamic ones.
All scheduled at app launch / after login using schedulePersonalized() called from main.dart or home_screen.dart after prefs load.

NOTIFICATION 1 — Morning Fuel Check (8:00 AM daily)
  Pull: userName (first name only), proteinGoal from UserPrefsService
  Message pool (pick random):
    title: "gm [name], ur protein ain't gonna eat itself"
    body: "you need [proteinGoal]g today. let's not fumble that."
    ---
    title: "rise and cook, [name]"
    body: "the ones who hit [proteinGoal]g protein every day? that's the looksmaxx arc fr."
    ---
    title: "today's agenda: cook, eat, glow"
    body: "target: [proteinGoal]g protein. make it happen."

NOTIFICATION 2 — Midday Macro Check (1:00 PM daily)
  Pull: proteinConsumed, proteinGoal from UserPrefsService (load stored values)
  remaining = proteinGoal - proteinConsumed
  If remaining > 0:
    title: "[remaining]g protein left. no slacking."
    body: "lunch szn. open Plately and don't fumble the bag."
  If remaining <= 0:
    title: "you actually ate [name]. W behavior."
    body: "protein goal cleared before 1pm. that's main character energy."

NOTIFICATION 3 — Streak Protection (6:30 PM — only if no cook logged today)
  Pull: streak from UserPrefsService
  If streak >= 3:
    title: "bro don't fumble the [streak]-day streak"
    body: "one recipe. 15 mins. protect the bag."
  If streak == 2:
    title: "2 days in a row is lowkey impressive ngl"
    body: "don't let day 3 be the one that kills the vibe."
  If streak == 1:
    title: "yesterday was day 1. today is day 2."
    body: "cook something. any recipe. just don't break the chain."
  If streak == 0:
    title: "no streak? no problem. start tonight."
    body: "even a 5-min Egg Fried Rice counts. open Plately."

NOTIFICATION 4 — Weekend Cook Inspo (Saturday 11:00 AM)
  Pull: last cooked recipe name from UserPrefsService (store lastCookedName on _finishCooking)
  title: "weekend is the looksmaxx arc era"
  body: "last time you cooked [lastCookedName]. try something harder today?"
  If no history:
    body: "no excuses on weekends. 60 recipes waiting. pick one."

NOTIFICATION 5 — Cook Done (one-shot, triggered after _finishCooking)
  title: "W cook, [name]"
  body: "+[cal]kcal · +[protein]g protein added. you're built different fr."
  (pass cal and protein as params to showCookingDoneNotification)

Implementation rules:
  - Use flutter_local_notifications scheduled notifications (already set up)
  - Random message selection: use Random().nextInt(pool.length) — seed with day of year for consistency
  - All scheduling happens in schedulePersonalized(Map<String,dynamic> prefs) — one method, called once after login
  - Cancel and reschedule on every app open so messages stay fresh with current data
  - Add: static Future<void> saveLastCookedName(String name) to UserPrefsService

File: frontend/lib/services/notification_service.dart — complete rewrite
File: frontend/lib/services/user_prefs_service.dart — add lastCookedName save/load
File: frontend/lib/screens/recipe_detail_screen.dart — pass cal, protein, name to notif; save lastCookedName
File: frontend/lib/screens/home_screen.dart — call NotificationService.schedulePersonalized(prefs) after _loadPrefs()
Output: all four files complete. No partial.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 28 COMPLETE, add to SESSION LOG, update CURRENT STATE.

---

### SESSION 29 — Filipino Content Domination + Search + Peso Pricing
**Status:** ✅ COMPLETE
**Goal:** 100 recipes, real regional Philippine variety, ₱ cost per serving, full-text search.

**What shipped:**
- database.py: cost_php column added to nutrition table (PG + SQLite schemas + ALTER TABLE migration guard). 40 new recipes added (10 Visayan/Cebuano, 10 Ilocano, 10 Bicolano/Mindanaoan, 10 budget Asian student meals). Duplicates removed from budget Asian block — all 100 recipes are unique. Every new recipe has a 5-tuple nutrition (cal, pro, carb, fat, cost_php).
- recipe.dart: costPhp field added — fromJson reads cost_php from nutrition dict, toJson writes it, copyWith includes it.
- recipe_card.dart: costPhp param added (default 0). ₱ cost chip renders below protein chip when costPhp > 0 — yellow/orange style.
- recipe_detail_screen.dart: ₱ cost per serving row added to nutrition card, only shows when r.costPhp > 0.
- recipe_results_screen.dart: costPhp: r.costPhp now passed to RecipeCard. Search bar was already complete from Session 27 ✅
- favorites_screen.dart: costPhp: r.costPhp passed to RecipeCard.
- backend/routes/recipes.py: both browse query and DB fallback SELECT n.cost_php, include cost_php in nutrition dict. image_url explicitly set in result dict.
- backend/routes/favorites.py: SQL includes n.cost_php, nutrition dict includes cost_php, image_url added to response dict.
- Flutter analyze: ✅ 0 issues (Session 29 verified)

---

### SESSION 30 — Free Distribution: Landing Page + Firebase App Distribution + Update Checker
**Status:** ⬜ NOT STARTED
**Goal:** people outside the team can actually find and install Plately without needing a Play Store account.
**All free. No paid services.**

#### ═══ SESSION 30 PROMPT — PASTE THIS INTO A NEW CLAUDE CHAT ═══

[paste MEMORY.md] [paste SKILLS.md] [paste TASKS.md]

SESSION 30 — Free Distribution Setup.
Goal: get Plately into strangers' hands without a Play Store listing.
Rules: full files only, flutter analyze 0 issues at end.

FIX 1 — In-app Update Checker
File: frontend/lib/services/update_service.dart — NEW FILE

UpdateService checks a free hosted JSON file (GitHub raw URL) on app launch:
  {
    "latest_version": "1.1.0",
    "download_url": "https://YOUR_GITHUB/releases/latest/download/app-release.apk",
    "message": "New recipes dropped. Update now fr."
  }

If remote version > current app version (read from package_info_plus or hardcoded const):
  Show a non-dismissable banner at bottom of HomeScreen:
    "🆕 New update just dropped — [message]"
    "Update" button → url_launcher opens download_url
    "Later" button → dismisses for this session only (not stored permanently)

File: frontend/lib/screens/home_screen.dart — call UpdateService.check() in initState, show banner if update available
File: pubspec.yaml — add package_info_plus if not already present
Output: update_service.dart + home_screen.dart complete. pubspec.yaml if changed.

FIX 2 — Landing Page HTML (deploy free on GitHub Pages)
Create file: plately-landing/index.html

A single self-contained HTML page (no frameworks, no npm, inline CSS):
Design: dark theme matching AppTheme.primaryDark (#043B3C), cream text (#F0EEE9)
Sections:
  1. Hero: Plately logo (text-based, Nunito font via Google Fonts), tagline "Know your macros BEFORE you cook. Not after.", CTA button "Download APK (Free)" → links to GitHub releases
  2. USP section: 3 cards — "Pre-cook macro awareness", "60+ Filipino recipes", "AI ingredient scan"
  3. Screenshots placeholder: 3 phone mockup outlines with labels (actual screenshots can be dropped in later)
  4. How it works: 3 steps — Scan ingredients → Get AI recipes → Cook + track macros
  5. Footer: "Made by students, for students. 🇵🇭" + GitHub link

The page must look legit — not like a school project. Gen-Z energy, clean, minimal.
Output: complete plately-landing/index.html. No partial.

FIX 3 — Firebase App Distribution setup guide
File: FIREBASE_DIST.md — NEW FILE at project root

Step-by-step guide (copy-paste ready commands):
  1. Install Firebase CLI: npm install -g firebase-tools
  2. firebase login
  3. firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
       --app YOUR_FIREBASE_APP_ID \
       --groups "testers" \
       --release-notes "Session 30 build — 100 recipes, offline mode, streak share cards"
  4. How to get Firebase App ID from google-services.json
  5. How to add tester emails in Firebase Console
  6. How to set up GitHub Action to auto-distribute on every push to main (free)

Also include the GitHub Action YAML:
  File: .github/workflows/distribute.yml
  Trigger: push to main
  Steps: checkout → setup flutter → build apk → firebase distribute

Output: FIREBASE_DIST.md + .github/workflows/distribute.yml complete.

AFTER ALL FIXES:
Run: flutter analyze — must be 0 issues. Paste exact output.
Update TASKS.md: mark SESSION 30 COMPLETE, add to SESSION LOG, update CURRENT STATE.
Tag: git tag v1.2.0 && git push --tags

---

## STATUS KEY
- [x] = done and verified
- [~] = in progress / partially done
- [ ] = not started

---

## COMPLETED FEATURES (Sessions 1–20)

| What | File(s) |
|------|---------|
| Google logo, history model, AI nav | home_screen, history_screen |
| Scan FAB, back button | main_shell, recipe_detail_screen |
| Mifflin-St Jeor goals dialog | profile_screen |
| Gemma AI chat + scan + recipe gen | chat.py, scan.py, recipes.py |
| user_id isolation, baseUrl dart-define | api_service.dart |
| Filipino tag + filter | recipes.py, recipe_results_screen |
| Chat rate limit per UID | chat.py |
| KeepAlive service | main.dart |
| Pantry screen (qty+unit+always-stocked) | pantry_screen.dart |
| Shopping list + Shopee deep-link | shopping_list_screen.dart |
| Notifications (3 scheduled + cook-done) | notification_service.dart |
| Recipe share card | recipe_detail_screen.dart |
| AI Chat model 404 fix | chat.py |
| AI Scan model fallbacks fixed | scan.py |
| My Pantry removed from Profile | profile_screen.dart |
| V2 references scrubbed | profile_screen.dart |
| Quick action icons polished | home_screen.dart |
| Pantry UI full redesign | pantry_screen.dart |
| Macro calendar | home_screen.dart |
| Dark mode — all screens | app_theme, main, all screens |
| Onboarding goals screen | onboarding_goals_screen.dart |
| Empty states (history + favorites) | history_screen, favorites_screen |
| Scan SnackBar | ingredient_entry_screen.dart |
| Backend validation + APK signing | recipes.py, favorites.py, key.properties |
| App icon + native splash | mipmap-*/, pubspec.yaml |
| Offline banner + wake-up banner | home_screen.dart |
| Recipe cache (SharedPrefs) | home_screen.dart, recipe.dart |
| Offline state in recipe results | recipe_results_screen.dart |
| RefreshIndicator — history + results | history_screen.dart, recipe_results_screen.dart |
| Privacy Policy + Edit Goals + app version | profile_screen.dart |
| CachedNetworkImage + shimmer + infinite scroll | recipe_card.dart, recipe_results_screen.dart |
| Backend gzip compression | app.py, requirements.txt |
| History calories_logged/protein_logged | history.py, database.py, history_screen.dart |
| Macro logging on Finish Cooking | recipe_detail_screen.dart |
| Wakeup banner (server-response-gated) | home_screen.dart |
| Google login goals check | login_screen.dart |

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
| 21 | imageUrl field in Recipe model + fromJson/toJson/copyWith, getRecipes timeout (30s), onboarding done flag (isOnboardingDone replaces calGoal==2200 sentinel) | recipe.dart, api_service.dart, user_prefs_service.dart, onboarding_goals_screen.dart, main.dart |
| 22 | Scan empty state recovery UI (Try Again / Type Instead buttons), recipe detail shimmer skeleton while fetching, timer haptic confirmed already wired | ingredient_entry_screen.dart, recipe_detail_screen.dart |
| 23 | didChangeDependencies macro ring refresh, Shopee clipboard fallback; favorites nutrition chips confirmed already present | home_screen.dart, shopping_list_screen.dart |
| 24 | 60 recipes with accurate dish-matched images, DB-backed AI cache, streak system (incrementStreak, 🔥 pill) | database.py, recipes.py, user_prefs_service.dart, recipe_detail_screen.dart, home_screen.dart |
| 25 | PG connection pooling (ThreadedConnectionPool), Cook Again empty SnackBar, key.properties verified, backend syntax validated, final audit scores | database.py, history_screen.dart, TASKS.md |
| 26 | Viral share card (PlatelyShareCard widget + _ShareBottomSheet), streak milestone popups (3/7/14/30 days), saveLastCookedName, flutter analyze 0 issues | plately_share_card.dart, recipe_detail_screen.dart, home_screen.dart, user_prefs_service.dart |
| 27 | Offline recipe browsing — sqflite cache service, offline banner + Retry in results, search bar with result count + no-results state, Offline chip badge + hidden Ask AI FAB in detail | offline_recipe_service.dart, recipe_results_screen.dart, recipe_detail_screen.dart |
| 28 | Hyperpersonalized notifications — full NotificationService rewrite: 5 dynamic notifs (Morning/Midday/Streak/Weekend/CookDone) with gen-Z copy using live name/macros/streak, schedulePersonalized() wired in HomeScreen, named params in notifyCookingDone | notification_service.dart, home_screen.dart, recipe_detail_screen.dart |
| 29 | ~100 recipes (40 new regional Filipino + budget Asian), cost_php column + nutrition tuple, ₱ chip on cards, ₱ row in detail, costPhp in Recipe model, cost_php in recipes.py + favorites.py API responses, duplicate recipes removed | database.py, recipe.dart, recipe_card.dart, recipe_detail_screen.dart, recipe_results_screen.dart, favorites_screen.dart, recipes.py, favorites.py |
| 30 | UpdateService (semver check vs GitHub raw version.json), update banner in HomeScreen (session-dismissable), landing page (plately-landing/index.html), GitHub Actions CI/CD workflow, FIREBASE_DIST.md setup guide, flutter analyze 0 issues | update_service.dart, home_screen.dart, plately-landing/index.html, .github/workflows/distribute.yml, FIREBASE_DIST.md |
