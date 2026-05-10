## CURRENT STATE (Session 35 — ✅ COMPLETE)

### Done this session (S35):
- **home_screen.dart** ✅ Hero greeting/headline, section headers, macro card "no log" row, AppBar logo theme-aware — all fixed
- **onboarding_goals_screen.dart** ✅ All sectionLabel, goalSelector, sexChip, targetRow, numField, showTargetEditor, header title — fixed
- **profile_screen.dart** ✅ _pwField, _showEditProfile TextField, bottom sheet titles, _PolicySection — fixed
- **ai_chat_screen.dart** ✅ Input bar fillColor, quick chips, empty state text — fixed
- **recipe_detail_screen.dart** ✅ Ingredients tab, steps tab, nutrition card, header, serving scaler — fixed
- **pantry_screen.dart + shopping_list_screen.dart** ✅ All const color regressions fixed
- **recipe_card.dart** ✅ Name/label colors, cost chip dark mode, maxLines confirmed

### Full S35 Audit Findings (new bugs discovered after source read):
- `_buildMacroRings()` in home_screen — dead method never called, still has hardcoded consts → **S36 FIX 1**
- `_clearAll()` AlertDialog in history_screen uses wrong context for Navigator.pop → **S36 FIX 2**
- `_finishCooking()` calls Navigator.pop after async gap without mounted check → **S36 FIX 3**
- Gluten-Free / Dairy-Free toggle in profile_screen is logically inverted → **S36 FIX 4**
- Retake button in ingredient_entry_screen wipes _ingredients → **S36 FIX 5**
- Multiple dark mode regressions remain in recipe_results, ai_chat header, history header, pantry empty state → **S37**
- Streak counter never resets on missed days → **S38**
- Calendar sheet future navigation has no upper bound → **S36 FIX 6**
- DELETE /api/history user_id may not be sent by client → **S39**

---

## SESSION 36 — START HERE NEXT

### 🔴 GOAL: Fix all critical bugs found in S35 audit. Zero crashes, zero logical inversions.

---

## ⚡ SESSION 36 PROMPT — CRITICAL BUG FIXES

```
[MEMORY.md] [SKILLS.md]

SESSION 36 GOAL: Fix 6 critical bugs found in the full S35 source audit.
Read EVERY file before touching it. Full files only. No partials.

RULES:
- Never use AppTheme.darkText or AppTheme.mutedText as const anywhere with BuildContext
- Always use textPrimary(context) and textMuted(context) in widgets
- Always check `if (!mounted) return;` before any setState or Navigator call after an await
- Full file output only — no "// ...rest stays the same"

---

## FIX 1 — home_screen.dart: Delete dead _buildMacroRings() method

Read home_screen.dart first with Desktop Commander read_file.

Find and DELETE the entire _buildMacroRings() method — it is never called anywhere
(search the file to confirm: no call site exists). It was superseded by _buildMacroCard()
in Session 30 but never removed. It still contains hardcoded const AppTheme.darkText
and AppTheme.mutedText that would break dark mode if called.

After deletion, run a mental flutter analyze:
- Confirm no other method references _buildMacroRings
- Confirm the file still has _buildMacroCard() intact (do NOT touch that)

---

## FIX 2 — history_screen.dart: Wrong context in _clearAll() AlertDialog

Read history_screen.dart first.

In _clearAll(), the showDialog builder has:
  builder: (dCtx) => AlertDialog(...)

Inside that AlertDialog, the two TextButton onPressed callbacks use:
  Navigator.pop(context, false)   ← WRONG — uses screen context
  Navigator.pop(context, true)    ← WRONG — uses screen context

This pops the whole History screen instead of just the dialog on some Flutter builds.

Fix: Change BOTH to use the dialog context:
  Navigator.pop(dCtx, false)
  Navigator.pop(dCtx, true)

While you have the file open, also fix the AlertDialog color regressions:
  - title TextStyle uses `const TextStyle(color: AppTheme.darkText)` → `TextStyle(color: AppTheme.textPrimary(dCtx))`
  - content TextStyle uses `AppTheme.mutedText` const → `AppTheme.textMuted(dCtx)`
  - "Cancel" TextButton text color `AppTheme.mutedText` → `AppTheme.textMuted(dCtx)`
  Both use `dCtx` since we're inside the builder.

---

## FIX 3 — recipe_detail_screen.dart: Stale context crash in _finishCooking()

Read recipe_detail_screen.dart first.

In _finishCooking(), after the Future.wait([...]) completes, there is:
  if (!mounted) return;
  setState(() => _finishLoading = false);
  ... ScaffoldMessenger snackbar ...
  await UserPrefsService.saveLastCookedName(r.name);
  final currentStreak = await UserPrefsService.getStreak();
  await Future.delayed(const Duration(milliseconds: 700));
  if (!mounted) return;
  _showShareSheet(...);
  Navigator.pop(context);    ← This is AFTER the 700ms delay

The issue: Navigator.pop(context) is AFTER the share sheet is shown. If the user
dismisses the share sheet themselves and navigates away in that 700ms, context is
deactivated. Additionally, the Navigator.pop should be inside a mounted check.

Fix: Ensure the final block reads:
  await Future.delayed(const Duration(milliseconds: 700));
  if (!mounted) return;
  _showShareSheet(cal: scaledCal, protein: scaledPro, streak: currentStreak);
  await Future.delayed(const Duration(milliseconds: 200));
  if (!mounted) return;
  Navigator.pop(context);

The second mounted check guards the pop after the share sheet call.

---

## FIX 4 — profile_screen.dart: Dietary preference toggle is logically inverted

Read profile_screen.dart first.

In _dietaryPrefs(), the switch/case for toggling Gluten-Free and Dairy-Free is inverted.
The data model stores: pref_gluten=false means gluten-free is ACTIVE.
But the toggle currently does savePrefGluten(on) — if the chip is currently ON (on=true),
it saves true (which means NOT gluten-free). This is backwards.

Current (WRONG):
  case 'Gluten-Free':
    await UserPrefsService.savePrefGluten(on);
    setState(() => _data['pref_gluten'] = on);
  case 'Dairy-Free':
    await UserPrefsService.savePrefDairy(on);
    setState(() => _data['pref_dairy'] = on);

Fix (CORRECT):
  case 'Gluten-Free':
    await UserPrefsService.savePrefGluten(!on);   // toggling OFF when currently on means allow gluten
    setState(() => _data['pref_gluten'] = !on);
  case 'Dairy-Free':
    await UserPrefsService.savePrefDairy(!on);
    setState(() => _data['pref_dairy'] = !on);

Verify the activePrefs Set at the top of _dietaryPrefs() is unchanged:
  if ((_data['pref_gluten'] as bool?) == false) 'Gluten-Free'
  if ((_data['pref_dairy']  as bool?) == false) 'Dairy-Free'
These are correct — pref_gluten=false = gluten-free active.

---

## FIX 5 — ingredient_entry_screen.dart: Retake button incorrectly wipes ingredients

Read ingredient_entry_screen.dart first.

In _cameraContent(), there is a GestureDetector for "Retake":
  GestureDetector(
    onTap: () => setState(() {
      _capturedPath = null;
      _ingredients = [];    ← THIS IS WRONG
      _scanError = null;
    }),

The user may have manually added ingredients via the type row before or after scanning.
Retake should only reset the scan state, NOT the ingredient list.

Fix: Remove `_ingredients = [];` from this setState call only:
  onTap: () => setState(() {
    _capturedPath = null;
    _scanError = null;
    _scanFailed = false;
    // _ingredients intentionally NOT cleared — user keeps manually added items
  }),

The existing _clearAndRetry() method correctly also resets _ingredients — that's fine
because that's an explicit "start over" action from the failed scan panel. Only the
"Retake" button (just below the chip panel) should NOT reset ingredients.

---

## FIX 6 — home_screen.dart: Calendar sheet has no upper bound on future navigation

Read home_screen.dart (if not already in context from FIX 1).

In _showCalendarSheet(), the StatefulBuilder has month navigation:
  TapScale(
    onTap: () => setSt(() => sheetMonth = DateTime(sheetMonth.year, sheetMonth.month + 1)),
    child: ... chevronRight ...
  )

This allows navigating to year 2050 with no limit. All future days show as disabled
(isFuture = true) but it's confusing UX.

Fix: Add a bound — disable the forward button when already at current month:
  final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final isAtCurrentMonth = sheetMonth.year == currentMonth.year && sheetMonth.month == currentMonth.month;

Then wrap the forward TapScale:
  TapScale(
    onTap: isAtCurrentMonth ? null : () => setSt(() => sheetMonth = DateTime(sheetMonth.year, sheetMonth.month + 1)),
    child: Container(
      ...
      child: Icon(LucideIcons.chevronRight,
        color: isAtCurrentMonth ? AppTheme.border(ctx) : AppTheme.primaryDark, size: 15),
    ),
  )

This greys out the forward arrow when on the current month. History dates can only
exist in the past or today, so going forward is always pointless.

---

## AFTER ALL FIXES:

Mental flutter analyze checklist:
- [ ] _buildMacroRings() is fully deleted from home_screen.dart — no compile error
- [ ] history_screen _clearAll() uses dCtx for both Navigator.pop calls
- [ ] AlertDialog in history_screen uses context-aware text colors
- [ ] recipe_detail_screen _finishCooking() has mounted checks before AND after share sheet
- [ ] profile_screen Gluten-Free/Dairy-Free saves !on not on
- [ ] ingredient_entry_screen Retake only clears _capturedPath, _scanError, _scanFailed
- [ ] home_screen calendar forward arrow is disabled at current month
- [ ] 0 new const TextStyle(color: AppTheme.darkText) introduced
- [ ] No new withOpacity — use withValues(alpha:) only

Update TASKS.md: mark Session 36 complete, paste Session 37 as next.
```

---

## ⚡ SESSION 37 PROMPT — REMAINING DARK MODE REGRESSIONS

```
[MEMORY.md] [SKILLS.md]

SESSION 37 GOAL: Fix all remaining dark mode color regressions found in S35 audit.
These were NOT fixed in S35 or S36. Read every file before touching it.

RULE: Never introduce const TextStyle with AppTheme.darkText or AppTheme.mutedText.
RULE: Full files only — no partial outputs, no "// ...rest stays the same".

---

## FIX 1 — ai_chat_screen.dart: Header "Ask Plately" title and subtitle invisible in dark mode

Read ai_chat_screen.dart first.

In the _Header widget's build() method:
  const Text('Ask Plately', style: TextStyle(
    color: AppTheme.darkText, ...))        ← WRONG: hardcoded const
  
  AnimatedSwitcher child Text(...):
    style: const TextStyle(color: AppTheme.mutedText, ...)  ← WRONG: hardcoded const

The _Header is a StatelessWidget — it receives BuildContext. Fix both:
  Text('Ask Plately', style: TextStyle(
    color: AppTheme.textPrimary(context), fontSize: 15,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w800))
  
  Text(..., style: TextStyle(color: AppTheme.textMuted(context), ...))
  
Remove const from both Text widgets and any const that wraps them.

---

## FIX 2 — ai_chat_screen.dart: _WelcomeView "Hi, I'm Plately" and "Try asking" invisible in dark

In _WelcomeView.build() (StatelessWidget — has BuildContext):
  const Text('Hi, I\'m Plately', style: TextStyle(
    color: AppTheme.darkText, ...))         ← WRONG
  
  const Align child Text('Try asking', style: TextStyle(
    color: AppTheme.darkText, ...))         ← WRONG

Fix both — remove const, use AppTheme.textPrimary(context).

Also check the subtitle paragraph Text — it uses:
  AppTheme.mutedText.withValues(alpha: 0.8)
This is fine as-is since it's not a const (withValues makes it dynamic).
But if it's wrapped in a const Text(), remove the const.

---

## FIX 3 — recipe_results_screen.dart: Header title and back button icon — dark mode

Read recipe_results_screen.dart first.

In _buildHeader():
  const Text(... color: AppTheme.darkText ...)   ← title text "Browse Recipes" / "Your Recipes"
  const Icon(LucideIcons.arrowLeft, color: AppTheme.darkText ...)  ← back icon

Fix title Text: use AppTheme.textPrimary(context)
Fix subtitle Text (ingredients list): use AppTheme.textMuted(context)  
The arrowLeft icon is inside a cardBg container — the darkText color is fine on light
but broken on dark. Fix: use AppTheme.primaryDark (always teal — this is intentional branding).
This matches all other screen back buttons.

---

## FIX 4 — recipe_results_screen.dart: Error/empty state texts — dark mode

Still in recipe_results_screen.dart.

_buildErrorState(), _buildOfflineState(), _buildNoSearchResults(), _buildEmpty() —
all have heading/body Text widgets with:
  const TextStyle(color: AppTheme.darkText)   ← invisible in dark mode
  const TextStyle(color: AppTheme.mutedText)  ← too low contrast in dark mode

Fix all of them:
  - Main heading text → AppTheme.textPrimary(context)
  - Secondary / description text → AppTheme.textMuted(context)
  
These are rendered on AppTheme.scaffoldBg — so they need context-aware colors.

---

## FIX 5 — recipe_results_screen.dart: Filter chip unselected text — dark mode

In _buildFilterRow():
  child: Text(f, style: TextStyle(
    color: active ? Colors.white : AppTheme.mutedText,   ← WRONG for dark
    ...))

AppTheme.mutedText = #7A7A7A which has poor contrast on dark card backgrounds.
Fix: color: active ? Colors.white : AppTheme.textMuted(context)

---

## FIX 6 — recipe_results_screen.dart: Shimmer AI loading label — dark mode

In _buildShimmer(), the AI generating text:
  const Text('AI is generating personalised recipes…',
    style: TextStyle(color: AppTheme.mutedText, ...))   ← const, won't adapt

Fix: remove const, use AppTheme.textMuted(context).

---

## FIX 7 — history_screen.dart: Header title "Your Activity" — dark mode

Read history_screen.dart (if not already in context).

In _header():
  const Text('Your Activity', style: TextStyle(color: AppTheme.darkText, ...))

The header has color: AppTheme.cardBg(context) background — so in dark mode
this dark text is invisible.

Fix: remove const, use AppTheme.textPrimary(context).

---

## FIX 8 — pantry_screen.dart: Empty state and header subtitle — dark mode

Read pantry_screen.dart first.

In _emptyState():
  const Text('Your fridge is empty',
    style: TextStyle(color: AppTheme.darkText, ...))   ← const, dark mode invisible
  const Text('Add ingredients you have at home',
    style: TextStyle(color: AppTheme.mutedText, ...))  ← const

Fix both — remove const, use textPrimary/textMuted(context).

In _header(), the subtitle "Track what you have at home":
  Text('Track what you have at home',
      style: TextStyle(color: AppTheme.textMuted(context), ...))
Verify this is already context-aware (it should be from S35). If still const, fix it.

---

## FIX 9 — ingredient_entry_screen.dart: Type mode empty state has no color style

Read ingredient_entry_screen.dart first.

In _typeContent(), the empty state Column texts:
  Text('No ingredients yet', style: TextStyle(fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))
  Text('Type above or switch to Camera', style: TextStyle(fontSize: 13, fontFamily: 'DM Sans'))

Both have NO color specified — they rely on Material theme default which may not
respect dark mode correctly with our custom themes.

Fix both — add color: AppTheme.textPrimary(context) and AppTheme.textMuted(context) respectively.

---

## FIX 10 — recipe_detail_screen.dart: Serving chip border and share button border — dark mode

Read recipe_detail_screen.dart first.

In _buildNutrition(), serving size picker chips:
  border: Border.all(color: selected ? AppTheme.primaryDark : AppTheme.borderGray)
  AppTheme.borderGray = #DADADA — invisible as border in dark mode.
  Fix: AppTheme.border(context)

In _buildActionBtn(), the share button:
  border: Border.all(color: AppTheme.borderGray)
  Fix: AppTheme.border(context)

---

## FIX 11 — profile_screen.dart: "Display" label in theme tile has no color

In _themeTile():
  const Text('Display', style: TextStyle(
    fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600))
  
No color — relies on Material theme default. Fix: add color: AppTheme.textPrimary(context),
remove const.

---

## AFTER ALL FIXES:

Mental flutter analyze checklist:
- [ ] No const TextStyle with AppTheme.darkText remaining in any of the fixed files
- [ ] No const TextStyle with AppTheme.mutedText remaining in any of the fixed files
- [ ] No AppTheme.borderGray used as a border color (use AppTheme.border(context))
- [ ] 0 analyzer issues expected

Run flutter analyze if Desktop Commander can reach the project terminal.
Report all issues found.

Update TASKS.md: mark Session 37 complete, paste Session 38 as next.
```

---

## ⚡ SESSION 38 PROMPT — STREAK RESET LOGIC + UX POLISH

```
[MEMORY.md] [SKILLS.md]

SESSION 38 GOAL: Fix streak reset logic (currently streaks never decay), fix Shopping List
Shopee fallback UX, and polish the Home screen pull-to-refresh to sync day data.

Read EVERY file before touching it. Full files only.

---

## FIX 1 — user_prefs_service.dart + home_screen.dart: Streak never resets on missed days

Read user_prefs_service.dart first, then home_screen.dart.

PROBLEM: incrementStreak() is only called in _finishCooking(). There is no code
that checks whether the user cooked yesterday and resets the streak if they didn't.
This means if a user cooks on Day 1, misses Day 2, and cooks on Day 3, their streak
shows as 2 (or more) instead of 1.

SOLUTION: Add a streak validity check in UserPrefsService.

Step 1 — Add to user_prefs_service.dart:
  - Add key: static const _kLastCookDate = 'last_cook_date';  // stores 'YYYY-MM-DD'
  
  - Add method:
    static Future<void> saveLastCookDate() async {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      await prefs.setString('${uid}_last_cook_date', dateStr);
    }
  
  - Add method:
    static Future<bool> isStreakStillValid() async {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final raw = prefs.getString('${uid}_last_cook_date');
      if (raw == null) return false;
      try {
        final lastCook = DateTime.parse(raw);
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final lastDay = DateTime(lastCook.year, lastCook.month, lastCook.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        final yesterdayDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
        // Valid if cooked today OR cooked yesterday (still within streak window)
        return lastDay == todayDay || lastDay == yesterdayDay;
      } catch (_) { return false; }
    }
  
  - Add method:
    static Future<void> resetStreakIfExpired() async {
      final valid = await isStreakStillValid();
      if (!valid) {
        await saveStreak(0);
      }
    }

Step 2 — Call saveLastCookDate() in recipe_detail_screen.dart inside _finishCooking():
  Add `UserPrefsService.saveLastCookDate()` to the Future.wait([...]) list in _finishCooking().
  It should go alongside the other UserPrefsService calls.

Step 3 — Call resetStreakIfExpired() in home_screen.dart inside _loadPrefs():
  At the START of _loadPrefs(), before loading data:
    await UserPrefsService.resetStreakIfExpired();
  Then proceed with the existing UserPrefsService.load() call.
  This ensures streak is reset on first open each day if no cook happened yesterday.

---

## FIX 2 — shopping_list_screen.dart: Shopee fallback copies wrong data

Read shopping_list_screen.dart first.

PROBLEM: _shopeeSearch(item) copies the ENTIRE remaining shopping list to clipboard
as a fallback when Shopee isn't installed. But this is triggered when the user taps
on a single item's "Shopee" button — they expect to search that ONE item, not get
the whole list dumped to clipboard.

Fix _shopeeSearch(String item):
  Replace the clipboard fallback with a web URL fallback that opens Shopee in browser:
  
  Future<void> _shopeeSearch(String item) async {
    final encoded = Uri.encodeComponent(item);
    // Try app deep link first
    final appUrl = Uri.parse('https://shopee.ph/search?keyword=$encoded');
    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      return;
    }
    // Fallback: open in browser (always works)
    final webUrl = Uri.parse('https://shopee.ph/search?keyword=$encoded');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.inAppBrowserView);
      return;
    }
    // Last resort: only now copy just THIS item to clipboard
    await Clipboard.setData(ClipboardData(text: item));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied "$item" to clipboard',
          style: const TextStyle(fontFamily: 'DM Sans')),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 2),
    ));
  }

---

## FIX 3 — home_screen.dart: Pull-to-refresh should also re-sync today's macro data

Read home_screen.dart.

PROBLEM: The onRefresh callback calls Future.wait([_loadPrefs(), _loadSuggested(), _loadHistory()])
but does NOT call _selectDay(today) to refresh the day macro display in _buildMacroCard().
If macros changed externally (e.g. logged on another session), the rings won't update.

Fix: In the RefreshIndicator's onRefresh:
  onRefresh: () async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    await Future.wait([_loadPrefs(), _loadSuggested(), _loadHistory()]);
    if (mounted) await _selectDay(today);
  },

This ensures the macro rings and day detail section refresh too.

---

## FIX 4 — home_screen.dart: Recent Activity empty state has no error handling

Read home_screen.dart.

PROBLEM: _loadHistory() catches nothing — if ApiService.getHistory() throws a network
error, _loadingHistory becomes false and _recentHistory stays empty with no user message.
The Recent Activity section just shows blank.

Fix: Wrap the API call in try/catch:
  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    try {
      final history = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _allHistory = history;
          _recentHistory = history.take(2).toList();
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingHistory = false; });
      // _recentHistory stays empty — _buildActivity() already handles empty state
    }
  }

---

## AFTER ALL FIXES:

Mental flutter analyze checklist:
- [ ] user_prefs_service.dart compiles — all new methods have correct return types
- [ ] recipe_detail_screen.dart Future.wait includes saveLastCookDate
- [ ] home_screen.dart calls resetStreakIfExpired at start of _loadPrefs
- [ ] shopping_list Shopee copies only the single item name as last resort
- [ ] Pull-to-refresh also calls _selectDay(today)
- [ ] _loadHistory() has try/catch

Update TASKS.md: mark Session 38 complete, paste Session 39 as next.
```

---

## ⚡ SESSION 39 PROMPT — BACKEND HARDENING + API AUDIT

```
[MEMORY.md] [SKILLS.md]

SESSION 39 GOAL: Harden backend API — fix user_id handling on DELETE history,
verify CORS is correctly locked down, and add missing input validation.

Read EVERY file before touching it. Full files only.

---

## FIX 1 — api_service.dart + history.py: DELETE history user_id sent correctly

Read frontend/lib/services/api_service.dart first, then backend/routes/history.py.

PROBLEM: delete_history_entry() in history.py gets user_id from request.args
(query string: DELETE /api/history/123?user_id=abc). Verify api_service.dart
sends user_id as a QUERY PARAMETER, not a body param (DELETE requests have no body
in standard HTTP).

In api_service.dart, find the deleteHistory method. It should look like:
  final uri = Uri.parse('$baseUrl/api/history/$id').replace(
    queryParameters: {'user_id': userId});
  await http.delete(uri, headers: _headers);

If it currently sends user_id in a body or not at all, fix it to use queryParameters.

Also check clear_history (DELETE /api/history) — same fix needed if user_id is missing.

Get userId from the same source used elsewhere in api_service.dart (Firebase Auth UID
or email string — check what the rest of the file uses for user_id).

---

## FIX 2 — history.py: Guard against empty/default user_id deleting wrong data

Read history.py.

In delete_history_entry() and clear_history():
  user_id = request.args.get('user_id', 'default')

If user_id comes in as 'default' or empty string, the WHERE clause will still execute
and may delete entries for the 'default' user (if any exist from early testing).

Add a guard:
  user_id = (request.args.get('user_id') or '').strip()
  if not user_id or user_id == 'default':
    return jsonify({"status": "error", "message": "user_id required"}), 400

Apply this guard to BOTH delete_history_entry and clear_history.
Do NOT apply to get_history or get_history_stats (those can fall back to 'default' for read-only).

---

## FIX 3 — app.py: Verify CORS is locked to correct origin

Read backend/app.py first.

Check the CORS configuration. It should use the ALLOWED_ORIGINS environment variable.
If it currently does CORS(app) with no origins restriction (allows all), update it to:

  import os
  from flask_cors import CORS
  allowed = os.getenv("ALLOWED_ORIGINS", "http://localhost:5000").split(",")
  CORS(app, origins=[o.strip() for o in allowed])

This means on Railway, setting ALLOWED_ORIGINS=https://plately-production.up.railway.app
will lock CORS correctly.

If CORS is already using an env var, verify the code is correct and leave it unchanged.
Report what you find.

---

## FIX 4 — recipes.py: Validate prefs dict to prevent injection via malformed prefs

Read recipes.py.

In get_recipes(), prefs comes from the request body. Currently:
  prefs = data.get("prefs") or {}
  if not isinstance(prefs, dict): prefs = {}

Add field-level validation and clamping:
  # After the isinstance check:
  cal_goal = prefs.get("cal_goal", 2200)
  protein_goal = prefs.get("protein_goal", 120)
  if not isinstance(cal_goal, (int, float)) or cal_goal < 500 or cal_goal > 10000:
    prefs["cal_goal"] = 2200
  if not isinstance(protein_goal, (int, float)) or protein_goal < 20 or protein_goal > 500:
    prefs["protein_goal"] = 120
  # Coerce booleans
  for k in ("pref_veg", "pref_gluten", "pref_dairy", "pref_hipro"):
    if k in prefs and not isinstance(prefs[k], bool):
      prefs[k] = bool(prefs.get(k, False))

This prevents malformed prefs from being injected into the AI prompt.

---

## FIX 5 — chat.py: Add user_id to rate limit key correctly

Read chat.py.

The _get_user_id() function already correctly prefers Firebase UID over IP.
Verify it's correctly called in the @bp.route decorator:
  @limiter.limit("15 per minute", key_func=_get_user_id)

If it's using get_remote_address instead of _get_user_id as key_func, fix it.
If it's already correct, confirm and move on.

Also verify MAX_MSG_LEN is enforced BEFORE the history is processed (it is —
just confirm the order: message truncation → history validation → _ask_ai).

---

## AFTER ALL FIXES:

Backend checklist:
- [ ] api_service.dart sends user_id as query param on DELETE calls
- [ ] history.py delete endpoints reject empty/default user_id
- [ ] app.py CORS uses ALLOWED_ORIGINS env var
- [ ] recipes.py validates prefs fields
- [ ] chat.py rate limit uses _get_user_id

Deployment note for Marco:
- Set Railway env var: ALLOWED_ORIGINS=https://plately-production.up.railway.app
- Redeploy after history.py changes

Update TASKS.md: mark Session 39 complete, paste Session 40 as next.
```

---

## ⚡ SESSION 40 PROMPT — FULL QA SMOKE TEST + FINAL DEPLOY PREP

```
[MEMORY.md] [SKILLS.md]

SESSION 40 GOAL: Run flutter analyze, verify all fixes from S36-S39 are in place,
run the full QA smoke test checklist, and prepare the final APK for Firebase App Distribution.

---

## STEP 1 — Run flutter analyze

Use Desktop Commander start_process to run:
  cd C:\Users\marcd\plately-v2\frontend && flutter analyze

Read the output. Fix any issues found before proceeding.
Expected result: 0 issues.

Common issues to expect and fix:
- Dead code warnings (remove them)
- Unused imports (remove them)
- Missing const (add them where safe — NOT on TextStyle with context-aware colors)
- Deprecated API usage

---

## STEP 2 — Verify all critical fixes from S36-S39

Read these files and confirm each fix is in place:

home_screen.dart:
- [ ] _buildMacroRings() method does NOT exist (deleted in S36)
- [ ] Calendar forward arrow is disabled at current month (S36 Fix 6)
- [ ] Pull-to-refresh calls _selectDay(today) (S38 Fix 3)
- [ ] _loadHistory() has try/catch (S38 Fix 4)
- [ ] _loadPrefs() calls resetStreakIfExpired() at start (S38 Fix 1)

history_screen.dart:
- [ ] _clearAll() AlertDialog uses dCtx for Navigator.pop (S36 Fix 2)
- [ ] AlertDialog title/body use textPrimary/textMuted(dCtx) (S36 Fix 2)
- [ ] Header "Your Activity" text uses textPrimary(context) (S37 Fix 7)

recipe_detail_screen.dart:
- [ ] _finishCooking() has mounted check before AND after share sheet (S36 Fix 3)
- [ ] Serving chip border uses AppTheme.border(context) (S37 Fix 10)
- [ ] Share button border uses AppTheme.border(context) (S37 Fix 10)

profile_screen.dart:
- [ ] Gluten-Free toggle saves !on (S36 Fix 4)
- [ ] Dairy-Free toggle saves !on (S36 Fix 4)
- [ ] "Display" label has textPrimary(context) color (S37 Fix 11)

ingredient_entry_screen.dart:
- [ ] Retake button does NOT clear _ingredients (S36 Fix 5)
- [ ] Type mode empty state texts have color styles (S37 Fix 9)

ai_chat_screen.dart:
- [ ] "Ask Plately" title uses textPrimary(context) (S37 Fix 1)
- [ ] Subtitle uses textMuted(context) (S37 Fix 1)
- [ ] "Hi, I'm Plately" uses textPrimary(context) (S37 Fix 2)
- [ ] "Try asking" label uses textPrimary(context) (S37 Fix 2)

recipe_results_screen.dart:
- [ ] Header title uses textPrimary(context) (S37 Fix 3)
- [ ] Error/empty state headings use textPrimary(context) (S37 Fix 4)
- [ ] Filter chips unselected text uses textMuted(context) (S37 Fix 5)
- [ ] Shimmer AI text uses textMuted(context) (S37 Fix 6)

pantry_screen.dart:
- [ ] Empty state texts use textPrimary/textMuted(context) (S37 Fix 8)

user_prefs_service.dart:
- [ ] saveLastCookDate() method exists (S38 Fix 1)
- [ ] isStreakStillValid() method exists (S38 Fix 1)
- [ ] resetStreakIfExpired() method exists (S38 Fix 1)

shopping_list_screen.dart:
- [ ] _shopeeSearch copies only single item name as last resort (S38 Fix 2)

api_service.dart:
- [ ] deleteHistory sends user_id as query param (S39 Fix 1)

backend/routes/history.py:
- [ ] delete endpoints reject empty/default user_id (S39 Fix 2)

backend/app.py:
- [ ] CORS uses ALLOWED_ORIGINS env var (S39 Fix 3)

---

## STEP 3 — QA Smoke Test Checklist (Marc runs on physical device)

### Light Mode:
- [ ] Home: greeting + headline visible, section headers visible
- [ ] Home: macro rings accurate, date pill opens calendar sheet
- [ ] Home: calendar cannot navigate past current month
- [ ] Recipe results: all filter chips readable, search bar text visible when typing
- [ ] Recipe results: error state readable if triggered
- [ ] Recipe detail: ingredients/steps/nutrition all readable
- [ ] Recipe detail: serving scaler chips have visible borders
- [ ] Recipe detail: Finish Cooking → macro logged → share sheet appears
- [ ] AI chat: input bar visible, can type and send
- [ ] AI chat header: "Ask Plately" visible in dark mode
- [ ] AI chat: multi-turn (3+ messages) works
- [ ] Profile: stat chips, goal bars, dietary pref chips all readable
- [ ] Profile: Gluten-Free toggle — tap ON, go to recipe results, verify gluten-free filter applied in prefs
- [ ] Profile: Display toggle Light/Dark/System all work
- [ ] Profile: Edit Goals → TDEE calc → values saved
- [ ] History: section headers, rows, 7-day chart readable
- [ ] History: Clear All → uses dialog → both Cancel and Clear work
- [ ] Favorites: header, chips, empty state visible
- [ ] Pantry: add item → appears. Swipe → deleted. Retake test below.
- [ ] Camera → scan → see chips → tap Retake → chips PRESERVED (not wiped)
- [ ] Type mode empty state: "No ingredients yet" visible in dark mode
- [ ] Shopping list: tap Shopee on individual item → opens shopee.ph for that item

### Dark Mode (Profile → Display → Dark):
- [ ] Home: greeting, headline, section headers all visible
- [ ] Recipe results: filter chips, error/empty states readable
- [ ] AI chat header "Ask Plately" and subtitle visible
- [ ] AI chat "Hi I'm Plately" welcome screen visible
- [ ] History: "Your Activity" header title visible
- [ ] History: Clear All dialog title/body visible
- [ ] Pantry: "Your fridge is empty" text visible
- [ ] Recipe detail: serving chip borders visible
- [ ] Profile: "Display" label visible

### Streak test:
- [ ] Cook a recipe → streak increments
- [ ] Change device date to 2 days later (developer options) → open app → streak resets to 0

### Backend:
- [ ] GET /api/health → {"status":"ok"}
- [ ] POST /api/recipes with ingredients → AI recipes or DB fallback returned
- [ ] POST /api/chat → reply received, multi-turn context preserved
- [ ] DELETE /api/history/ID?user_id=X → only deletes correct user's entry

---

## STEP 4 — Build release APK

Run:
  cd C:\Users\marcd\plately-v2\frontend
  flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-production.up.railway.app

Verify no build errors. APK output at:
  build/app/outputs/flutter-apk/app-release.apk

---

## STEP 5 — Push to main → Firebase App Distribution

- [ ] git add -A && git commit -m "S36-S39: critical bug fixes + dark mode + backend hardening"
- [ ] git push origin main
- [ ] GitHub Actions distribute.yml triggers automatically
- [ ] Confirm APK appears in Firebase App Distribution console
- [ ] Add tester emails in Firebase Console → App Distribution → Testers

---

Update TASKS.md: mark Session 40 complete, add post-ship backlog below.
```

---

## PRE-DEPLOY CHECKLIST

### Marco (backend):
- [x] Railway backend live at https://plately-production.up.railway.app ✅
- [x] Neon DB connected + seeded (~100 recipes) ✅
- [x] cron-job.org keepalive every 10 min ✅
- [ ] Set ALLOWED_ORIGINS in Railway Variables = https://plately-production.up.railway.app
- [ ] Redeploy after history.py + app.py changes (S39)

### Marc (frontend):
- [x] Keystore at frontend/android/upload-keystore.jks ✅
- [x] GitHub secrets set (all 7) ✅
- [x] distribute.yml keystore path fixed ✅
- [x] permission_handler: ^11.3.1 in pubspec ✅
- [ ] flutter pub get (confirm done after S33)
- [ ] S36–S39 fixes merged to main
- [ ] flutter analyze → 0 issues
- [ ] Release APK builds successfully
- [ ] Firebase App Distribution → add tester emails

---

## BACKLOG (post v1.1)
- [ ] Recipe rating / cook count
- [ ] Custom recipe notes per-user
- [ ] Ingredient substitution AI ("I don't have X")
- [ ] Shopping list → share as plain text (WhatsApp/SMS)
- [ ] Sentry error monitoring (free tier)
- [ ] Pantry header badge: split "X in fridge / Y always stocked"
- [ ] Recipe detail timer: persist across tab switch (nice-to-have)
- [ ] AI Chat: show "history trimmed" badge on sessions > 30 messages
- [ ] Home Recent Activity: show "couldn't load" message on network error

---

## STATUS KEY
- [x] = done and verified from source
- [~] = in progress / partial
- [ ] = not started

---

## SESSION LOG

| Session | What Was Done | Key Files |
|---------|---------------|-----------|
| 1–31 | See prior TASKS.md | — |
| 32 | Full source audit — 6 fix queues written | TASKS.md |
| 33 | history.py crash fix, camera permission flow, profile theme toggle, icon fixes | history.py, ingredient_entry_screen.dart, profile_screen.dart, ai_chat_screen.dart, pubspec.yaml |
| 34 | chat.py Gemma fix, camera error overlay, dark mode: history/profile/favorites | chat.py, ingredient_entry_screen.dart, history_screen.dart, profile_screen.dart, favorites_screen.dart |
| 35 | Dark mode fixes: home, onboarding, profile, ai_chat, recipe_detail, pantry, shopping, recipe_card. Full source audit → 4 critical bugs + 11 logic issues found | All screens |
| 36 | [NEXT] Delete dead _buildMacroRings, fix AlertDialog context, fix _finishCooking mounted check, fix dietary toggle inversion, fix retake wipes ingredients, fix calendar upper bound | home_screen, history_screen, recipe_detail_screen, profile_screen, ingredient_entry_screen |
| 37 | [QUEUED] Dark mode regressions: ai_chat header, welcome view, recipe_results states/chips, history header, pantry empty state, ingredient_entry empty state, recipe_detail borders, profile display label | ai_chat_screen, recipe_results_screen, history_screen, pantry_screen, ingredient_entry_screen, recipe_detail_screen, profile_screen |
| 38 | [QUEUED] Streak reset logic, Shopee fallback UX fix, pull-to-refresh day sync, _loadHistory try/catch | user_prefs_service, recipe_detail_screen, home_screen, shopping_list_screen |
| 39 | ✅ Backend hardening: api_service.dart DELETE already correct (query param), history.py guards added (400 on empty/default user_id), app.py CORS simplified to ALLOWED_ORIGINS defaulting *, recipes.py prefs clamping + bool coercion added, chat.py _get_user_id already correct | history.py, app.py, recipes.py |
| 40 | [NEXT] flutter analyze, verify all fixes, full QA smoke test, release APK build, Firebase App Distribution | All files |
