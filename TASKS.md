# PLATELY V2 — TASKS.md
> Paste alongside MEMORY.md + SKILLS.md at start of every chat.
> Last updated: Session 44 — Full source audit. Sessions A, B (partial), E, F verified DONE in source. TASKS.md, MEMORY.md, SKILLS.md updated to reflect actual code state.

---

## ⚠️ HOW TO KEEP THIS FILE ACCURATE
This file must be updated AT THE END OF EVERY SESSION without exception.

---

## CURRENT STATE (Session 44 — Post source audit ✅)

### Done in S44 (Source Audit — verified against actual files on disk):
- Confirmed Sessions A, B (most items), E, F are already implemented in source
- TASKS.md, MEMORY.md, SKILLS.md updated to reflect true state
- Items previously marked ⬜ in bug queue but actually DONE in source → flipped to ✅

### Still pending (human tasks):
- ⬜ Marco: set `ALLOWED_ORIGINS=https://plately-production.up.railway.app` in Railway Variables
- ⬜ Marco: redeploy backend after setting ALLOWED_ORIGINS
- ⬜ Marc/Adrian: add tester emails in Firebase Console → App Distribution → Testers
- ⬜ Marc: commit + push all changes, rebuild APK

---

## 🐛 BUG QUEUE — TRUE STATUS (verified against source S44)

> Priority: P0=crash/data loss | P1=broken feature | P2=wrong behavior | P3=visual only

| Priority | Screen | Description | Session | Status |
|----------|--------|-------------|---------|--------|
| P3 | Splash | 3 splash screens → should be 1 branded splash | A | ✅ DONE (single splash + first-time carousel) |
| P1 | Login (light) | Input fields: sharp vs rounded border mismatch | A | ✅ DONE (_AuthField uses AnimatedContainer with consistent radius 14) |
| P1 | Login (dark) | Input field bg ≈ text color — unreadable | A | ✅ DONE (S43) |
| P2 | Login (dark) | Wrong dark mode — scaffold bg not adapting | A | ✅ DONE (S43) |
| P2 | Forgot Password | No clarification it only resets Plately password | A | ✅ DONE (S43 — sheet says "Plately password only") |
| P1 | Goals | Male/Female selector misaligned | B | ✅ DONE (both _sexChip() are Expanded, height 44) |
| P1 | Goals | TDEE result not reflected in daily targets | B | ✅ DONE (_calculate() does setState on result) |
| P0 | Goals | After Save → black screen | B | ✅ DONE (pushAndRemoveUntil with canPop() guard) |
| P3 | Home | Logo renders as square with bg color | B | ✅ N/A (uses PlatelyLogo widget — no raw asset) |
| P1 | Home (dark) | Macro/text info barely visible in dark mode | B | ✅ DONE (S43 partial + uses textPrimary/textMuted) |
| P1 | Home | Scan FAB label garbled 'aE' text | B | ✅ DONE (_ScanFab is clean circle, no label) |
| P1 | Browse (light) | Search text field missing corner borders | C | ⬜ NEEDS FIX |
| P1 | Recipe Detail (dark) | Tab buttons barely visible | C | ⬜ NEEDS FIX |
| P2 | Recipe Detail | Favorite heart: delay + bg turns red | C | ⬜ NEEDS FIX |
| P3 | Recipe Detail | Finish cooking animation too fast | C | ⬜ NEEDS FIX |
| P2 | Recipe Detail | Steps UX: tap to mark done | C | ⬜ NEEDS FIX |
| P2 | Recipe Detail | Ingredient chip — unclear if changes macros | C | ⬜ NEEDS FIX |
| P1 | Shopping List | "All in pantry" when pantry is empty | C | ⬜ NEEDS FIX |
| P1 | Timer | Pauses when app switches — needs deadline-based | D | ⬜ NEEDS FIX |
| P1 | Timer | No notification when user in another app | D | ⬜ NEEDS FIX |
| P0 | Camera | White/blank viewfinder | D | ⬜ NEEDS FIX |
| P1 | Scan (dark) | Overall scan page UI poor in dark mode | D | ⬜ NEEDS FIX |
| P1 | Scan type (light) | Text field missing corner edges | D | ⬜ NEEDS FIX |
| P1 | Ask Plately (dark) | Send button invisible | D | ⬜ NEEDS FIX |
| P1 | Ask Plately (dark) | Duplicate text field visible | D | ⬜ NEEDS FIX |
| P1 | Ask Plately | /api/chat returns internal error | G | ✅ DONE (S43 logging+guards added) |
| P2 | History | Timestamps military time + GMT | E | ✅ DONE (_formatTimestamp() human-friendly) |
| P1 | History | Tapping entry navigates wrong | E | ✅ DONE (_openHistoryEntry() uses recipe_id) |
| P2 | History | 7-day overview poor layout | E | ✅ DONE (full _weeklyCalendar() Mon–Sun bars + nav) |
| P1 | Profile | Gluten-Free & Dairy-Free chips not toggling | F | ✅ DONE (correct inversion logic in toggle()) |
| P2 | Profile | No High Protein explanation | F | ✅ DONE (info container shown when isHiPro) |
| P3 | Profile | Theme picker plain pills → icon+label rows | F | ✅ DONE (_themeRow() with icon + label + checkmark) |
| P1 | Pantry (light) | Text field sharp/rounded inconsistency | F | ✅ DONE (uses AppTheme.inputDecoration()) |
| P1 | Global | Text fields inconsistent light/dark | G | ✅ DONE (S43 inputDecoration helper) |
| P1 | Global (dark) | Dark mode visibility widespread | G | ✅ DONE (S43 — login, signup, home, onboarding, ai_chat, recipe_results) |

---

## 🔧 REMAINING FIX SESSION PROMPTS
> Only Sessions C and D remain. Run these next.

---

### SESSION C — Browse / Recipe Results & Recipe Detail & Shopping List
**Files:** `recipe_results_screen.dart`, `recipe_detail_screen.dart`, `shopping_list_screen.dart`
**Note:** recipe_results_screen shimmer dark mode fixed in S43. Session E items (history) all done in source.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

SCREENS: recipe_results_screen.dart, recipe_detail_screen.dart, shopping_list_screen.dart

FIXES NEEDED:

1. BROWSE SEARCH FIELD LIGHT MODE: The search bar uses a Container + TextField with
   InputBorder.none. In light mode the border clips or goes missing. Ensure the outer
   Container has borderRadius: BorderRadius.circular(12) + Border.all(color: AppTheme.border(context)).
   Also verify the inner TextField has InputBorder.none so there's no double border.

2. RECIPE DETAIL DARK MODE — TABS: TabBar labelColor / unselectedLabelColor must use
   AppTheme.textPrimary(context) for selected and AppTheme.textMuted(context) for unselected.
   TabBar indicatorColor → AppTheme.primaryDark.

3. FAVORITE BUTTON — Two bugs:
   a) Delay: move setState() for optimistic UI BEFORE the async API call. Revert on failure.
   b) Wrong element: ONLY the Icon color changes to AppTheme.red — NOT a container background.
      IconButton with icon: Icon(LucideIcons.heart, color: _isFavorited ? AppTheme.red : AppTheme.iconColor(context))

4. FINISH COOKING ANIMATION: Slow to at least 1200ms.
   Use flutter_animate with duration: const Duration(milliseconds: 1200).

5. STEPS UX — MARK AS DONE: Add List<bool> _completedSteps. On tap, toggle → setState().
   Completed: TextDecoration.lineThrough + AppTheme.textMuted(context) + checkmark icon.

6. INGREDIENT CHIPS LABEL: Add helper text below ingredient list:
   "Tap to check off — macros are pre-calculated for the full recipe."
   TextStyle: AppTheme.textMuted(context), 12px DM Sans.

7. SHOPPING LIST — WRONG EMPTY STATE: Only exclude ingredient if it ACTUALLY EXISTS in
   pantry list. If pantry is empty → show all recipe ingredients.
   Audit _buildShoppingList(): the pantry cross-reference must check actual list contents.

Output complete replacement files.
```

---

### SESSION D — Timer, Camera / Scan & Ask Plately UI
**Files:** `ingredient_entry_screen.dart`, `ai_chat_screen.dart`, `recipe_detail_screen.dart` (timer only)
**Note:** ai_chat_screen welcome subtitle + markdown code bg fixed in S43.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

SCREENS: ingredient_entry_screen.dart, ai_chat_screen.dart, recipe_detail_screen.dart (timer only)

NOTE: ai_chat_screen welcome subtitle dark mode and markdown code block bg fixed in S43.
Do NOT re-fix those. Focus only on items below.

FIXES NEEDED:

1. STEP TIMER — BACKGROUND SAFE: Replace Timer.periodic with deadline-based timer.
   On start: save endTime = DateTime.now().add(duration). Each tick: compute
   remaining = endTime.difference(DateTime.now()). Catches up correctly on resume.

2. STEP TIMER — NOTIFICATION: Use flutter_local_notifications one-shot notification
   at timer end via zonedSchedule. Label: "Timer done — Step [N]".
   Same pattern as cook-done notifications in NotificationService.

3. CAMERA VIEWFINDER — WHITE SCREEN (P0): CameraPreview renders white/blank.
   Fix: await _controller.initialize() fully, then setState(). Guard:
   if (_controller == null || !_controller!.value.isInitialized) return LoadingSpinner().
   Verify didChangeAppLifecycleState correctly re-initializes on resume.

4. SCAN PAGE DARK MODE: Scaffold, AppBar, bottom sheets use AppTheme.scaffoldBg(context)
   and AppTheme.cardBg(context). All text uses AppTheme.textPrimary(context).
   Chip labels visible on dark backgrounds.

5. SCAN TYPE MODE — TEXT FIELD: Apply AppTheme.inputDecoration() helper for consistent
   OutlineInputBorder radius 12 in both light and dark mode.

6. ASK PLATELY DARK MODE — SEND BUTTON: Verify hasText && !loading condition shows
   AppTheme.tealGradient. Check _InputBar's container background in dark mode.

7. ASK PLATELY DARK MODE — DOUBLE TEXT FIELD: Find and remove the duplicate TextField
   in _InputBar. There should be exactly ONE TextField for input.

Output complete replacement files.
```

---

## PRE-DEPLOY CHECKLIST

### Marco (backend):
- [x] Railway backend live ✅
- [x] Neon DB connected + seeded ✅
- [x] cron-job.org keepalive ✅
- [x] history.py DELETE guards ✅ S39
- [x] app.py CORS uses ALLOWED_ORIGINS env var ✅ S39
- [x] recipes.py prefs validation ✅ S39
- [x] chat.py error logging + OpenRouter guards ✅ S43
- [ ] Set ALLOWED_ORIGINS in Railway Variables ← STILL NEEDED
- [ ] Redeploy after setting ALLOWED_ORIGINS

### Marc (frontend):
- [x] Keystore path fixed ✅ S40
- [x] flutter analyze → 0 issues ✅ S43
- [x] Release APK built (64MB) ✅ S40
- [ ] Commit + push all changes ← DO THIS
- [ ] Run Sessions C + D
- [ ] Rebuild APK after C + D done
- [ ] Firebase App Distribution → add tester emails ← STILL NEEDED

---

## SESSION LOG

| Session | What Was Done | Key Files |
|---------|---------------|-----------|
| 1–31 | See prior TASKS.md | — |
| 32 | Full source audit — 6 fix queues written | TASKS.md |
| 33 | history.py crash fix, camera permission flow, profile theme toggle, icon fixes | history.py, ingredient_entry_screen.dart, profile_screen.dart, ai_chat_screen.dart, pubspec.yaml |
| 34 | chat.py Gemma fix, camera error overlay, dark mode: history/profile/favorites | chat.py, ingredient_entry_screen.dart, history_screen.dart, profile_screen.dart, favorites_screen.dart |
| 35 | Dark mode fixes: home, onboarding, profile, ai_chat, recipe_detail, pantry, shopping, recipe_card | All screens |
| 36 | Deleted dead _buildMacroRings, fixed AlertDialog dCtx, fixed _finishCooking mounted checks, dietary pref toggle inversion, retake not wiping ingredients, calendar upper bound | home_screen.dart, history_screen.dart, recipe_detail_screen.dart, profile_screen.dart, ingredient_entry_screen.dart |
| 37 | Dark mode regressions: ai_chat header + welcome, recipe_results states/filter/shimmer, history header, pantry empty, ingredient_entry type empty, recipe_detail borders, profile Display label | All screens |
| 38 | Streak reset logic, Shopee fallback browser fix, pull-to-refresh day sync, _loadHistory try/catch | user_prefs_service.dart, recipe_detail_screen.dart, home_screen.dart, shopping_list_screen.dart |
| 39 | Backend hardening: DELETE guards, CORS env var, prefs validation, rate limit verified | history.py, app.py, recipes.py |
| 40 | flutter analyze 0 issues, all S36-S39 fixes verified, keystore path fixed, APK built + shipped | All files |
| 41 | QA test plan written (111 TCs). Marc ran tests. | TASKS.md |
| 42 | QA observations logged by Adrian. 7 fix sessions (A–G) written. | TASKS.md |
| 43 | Session G done: inputDecoration helper, login/signup dark mode, home milestone dialog, onboarding label styles, ai_chat welcome subtitle, shimmer dark mode, chat.py error logging. flutter analyze 0 issues. | app_theme.dart, login_screen.dart, signup_screen.dart, home_screen.dart, onboarding_goals_screen.dart, ai_chat_screen.dart, recipe_results_screen.dart, chat.py |
| 44 | Full source audit — Sessions A, B, E, F verified done in actual source files. TASKS.md/MEMORY.md/SKILLS.md updated. Only Sessions C + D remain. | TASKS.md, MEMORY.md, SKILLS.md |

---

## BACKLOG (post v1.0)
- [ ] Home Recent Activity: show "couldn't load" on network error
- [ ] Shopping list → share as plain text (WhatsApp/SMS)
- [ ] Recipe rating / cook count
- [ ] Custom recipe notes per-user
- [ ] Ingredient substitution AI ("I don't have X")
- [ ] Sentry error monitoring (free tier)
- [ ] Pantry header badge: split "X in fridge / Y always stocked"
- [ ] Recipe detail timer: persist across tab switch
- [ ] AI Chat: show "history trimmed" badge on sessions > 30 messages
- [ ] Recipe detail: Cook Again pre-scales to last used serving size
