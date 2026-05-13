# PLATELY V2 — TASKS.md
> Paste alongside MEMORY.md + SKILLS.md at start of every chat.
> Last updated: Session M — 6 new device-tested bugs logged after Session L deploy. Sessions M + N + Full Backend Audit written. Ready to execute.

---

## ⚠️ HOW TO KEEP THIS FILE ACCURATE
This file must be updated AT THE END OF EVERY SESSION without exception.

---

## CURRENT STATE (SESSION M — PENDING)

### Done in Session L deploy:
- Google Sign-In: added `serverClientId` to `GoogleSignIn()` ✅
- AI models: switched to llama-3.3-8b + mistral-7b fallback ✅
- Camera: added `_cam!.value.isInitialized` gate ✅
- Favorites empty state: redesigned with illustration + Browse button ✅
- APK rebuilt + deployed to Railway + uploaded to Firebase ✅

### New bugs found after Session L device test:
- Google Sign-In still failing (root cause: deeper OAuth config issue, not just serverClientId)
- AI chat: "All AI models failed" — OpenRouter free key exhausted, need new key
- Camera preview stretched — missing AspectRatio wrapper
- Redundant input field shown in camera mode after scan failure
- Black screen after navigating back from scan (pushReplacement bug)
- "Browse Recipes" button goes to Home tab, not a recipe browse experience

### Pending:
- ⬜ Run Session M — fix all 6 bugs above (frontend + backend)
- ⬜ Get new OpenRouter API key and update Railway env var
- ⬜ Rebuild APK after Session M
- ⬜ Redeploy Railway after Session M
- ⬜ Run Session N — full backend audit
- ⬜ Re-upload to Firebase App Distribution

---

## 🐛 BUG QUEUE

> Priority: P0=crash/data loss | P1=broken feature | P2=wrong behavior | P3=visual only

| Priority | Screen | Description | Session | Status |
|----------|--------|-------------|---------|--------|
| P1 | Auth | Google Sign-In still failing after serverClientId fix — deeper OAuth config issue on Google Cloud Console | M | ⬜ OPEN |
| P1 | AI Chat | "All AI models failed" — OpenRouter free key rate-limited/exhausted. Need new OPENROUTER_API_KEY in Railway env | M | ⬜ OPEN |
| P1 | Scan / Camera | Camera preview is stretched — CameraPreview fills screen without AspectRatio wrapper | M | ⬜ OPEN |
| P2 | Scan / Camera | Redundant text input field shown in camera mode after scan failure — user already has "Type Instead" button | M | ⬜ OPEN |
| P1 | Scan / Camera | Black screen after going back from scan — `Navigator.pushReplacement` in `_findRecipes()` removes scan from stack, back from RecipeResults skips scan and hits black transition | M | ⬜ OPEN |
| P2 | Favorites | "Browse Recipes" empty state button navigates to Home tab (tab 0) instead of launching a recipe browsing experience | M | ⬜ OPEN |
| P1 | Goals | Calculate TDEE does not visually reflect updated targets in UI — state update not triggering rebuild | L | ⬜ OPEN |
| P1 | App icon | Launcher icon dull/low contrast on home screen | H | ✅ DONE SH |
| P1 | Auth | Google Sign-In fails — only Gmail accounts work | H | ✅ DONE — SHA-1 added to Firebase |
| P1 | Goals | Calculate TDEE button does not update displayed targets | H | ✅ VERIFIED — already wired in source |
| P1 | Home (dark) | No contrast — text/icons barely visible | I | ✅ DONE SI — borderGray fix |
| P1 | Home (dark) | Logo shows box/background in dark mode | I | ✅ VERIFIED SI — already fixed (showBg=false hardcoded) |
| P2 | Home (dark) | Date label ("May 12") has no highlight, barely visible | I | ✅ VERIFIED SI — uses primaryDark pill, fine |
| P1 | Home (dark) | Recent Activity rows use hardcoded white bg (ActivityRow widget) | I | ✅ VERIFIED SI — already clean |
| P1 | Favorites | Heart icon only outlines red — fill should be solid red when active | I | ✅ DONE SI — isFavorited badge on RecipeCard |
| P1 | Favorites | Search field missing rounded corners in light mode | I | ✅ VERIFIED SI — already has borderRadius 14 + border |
| P2 | Recipe Detail | Finish cooking share sheet opens and closes instantly — user can't read it | J | ✅ VERIFIED SJ — already has Done button + no auto-dismiss |
| P2 | Recipe Detail | Tab divider visible in dark mode but invisible in light mode | J | ✅ VERIFIED SJ — already has border: Border.all(AppTheme.border) |
| P2 | Recipe Detail | No visual hint that steps are tappable to mark done | J | ✅ VERIFIED SJ — hint row already present |
| P1 | Camera / Scan | Camera viewfinder still white/blank on physical device | J | ✅ VERIFIED SJ — already uses direct Positioned.fill, no AnimatedOpacity |
| P1 | Scan (dark) | Overall scan UI poor in dark mode | J | ✅ DONE SJ — _PillTab/Chip static colors fixed |
| P1 | Scan type | Text/search field missing corners in both light and dark mode | J | ✅ VERIFIED SJ — borderRadius 16 + AppTheme.border already present |
| P1 | Profile | Dietary preferences layout/display needs redesign | K | ✅ DONE SK |
| P2 | Profile | Theme picker (Light/Dark/System) display issues | K | ✅ VERIFIED — already correct in source |
| P1 | Global | Full UI audit: contrast, font sizes, button sizes, highlights | K | ✅ DONE SK — all static color violations cleared |
| P1 | Backend | All APIs need live verification — chat, scan, recipes, goals, history | K | ✅ DONE SK — model updated gemma-3→4, all endpoints passing |

---

## 🔧 REMAINING SESSION PROMPTS

---

### SESSION M — Google Sign-In Deep Fix + OpenRouter Key + Camera + Scan UX + Navigation Bug + Browse Button
**Files:** `auth_service.dart`, `ingredient_entry_screen.dart`, `favorites_screen.dart`, `onboarding_goals_screen.dart`
**Root causes:**
- **Google Sign-In:** `serverClientId` is now set but sign-in still fails. Root cause: the `google-services.json` has two Android OAuth clients (SHA-1 hashes) but Google Cloud Console may not have the web client OAuth consent screen fully configured, OR the `signOut()` before `signIn()` is resetting state in a way that breaks the flow on some Android versions. Fix: remove the `_google.signOut()` pre-call, add detailed PlatformException logging to surface the actual error code.
- **AI Chat:** OpenRouter free key is exhausted. Marco must create a new OpenRouter account at openrouter.ai, generate a new free API key, and update the `OPENROUTER_API_KEY` env var in Railway. No code change needed — just env var update. Document the steps clearly.
- **Camera stretched:** `CameraPreview` inside `Positioned.fill` stretches to fill the screen ignoring the camera sensor's natural aspect ratio. Fix: wrap `CameraPreview` in `AspectRatio(aspectRatio: _cam!.value.aspectRatio)` and center it inside the `Positioned.fill` using a `Center` widget.
- **Redundant input in camera fail state:** After a failed scan, `_addRow(dark: true)` appears below the chip panel even though "Type Instead" button already switches mode. Remove `_addRow` from `_cameraContent()` entirely — it only belongs in `_typeContent()`.
- **Black screen on back:** `_findRecipes()` calls `Navigator.pushReplacement` which removes `IngredientEntryScreen` from the stack. When user goes back from `RecipeResultsScreen`, they land on whatever is beneath scan (MainShell transition = black flash). Fix: change to `Navigator.push` so the back button returns to the scan screen with ingredients intact.
- **Browse Recipes button:** `MainShell.switchTab(0)` goes to Home. Change to open `RecipeResultsScreen` with an empty ingredients list (shows the full recipe browse/grid with filters). Use `Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: [])))`.
- **TDEE not reflecting:** The `_targetsCard()` already reads from `_calGoal`/`_proteinGoal` state. But `_calculate()` wraps the setState in a try/catch that silently swallows API errors. Add explicit error snackbar in the catch block so the user knows if the API failed.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES TO CHANGE:
- frontend/lib/services/auth_service.dart
- frontend/lib/screens/ingredient_entry_screen.dart
- frontend/lib/screens/favorites_screen.dart
- frontend/lib/screens/onboarding_goals_screen.dart

FIXES NEEDED:

1. GOOGLE SIGN-IN — REMOVE PRE-SIGNOUT + BETTER ERROR LOGGING (auth_service.dart — P1):
   a) In signInWithGoogle(), REMOVE the `await _google.signOut()` line before signIn().
      This pre-signout causes issues on some Android versions by resetting the OAuth
      state mid-flow.
   b) In the catch block for generic exceptions, add PlatformException handling:
      } on PlatformException catch (e) {
        logger.error or print: 'Google Sign-In PlatformException: ${e.code} — ${e.message}'
        return AuthResult.error('Google sign-in failed (${e.code}). Contact support.');
      }
      Import: import 'package:flutter/services.dart';
   c) Keep everything else the same — serverClientId stays as is.
   Output complete replacement for auth_service.dart.

2. OPENROUTER NEW KEY — INSTRUCTIONS ONLY (no code change):
   The OpenRouter free API key is exhausted. Steps to fix:
   a) Go to https://openrouter.ai and create a new account with a different email.
   b) Generate a free API key from the dashboard.
   c) In Railway dashboard → mindful-presence project → Variables tab:
      Update OPENROUTER_API_KEY to the new key value.
   d) Railway will auto-redeploy. Test /api/chat after redeploy.
   No code changes needed for this fix — document clearly in session log.

3. CAMERA ASPECT RATIO — FIX STRETCH (ingredient_entry_screen.dart — P1):
   In the build() method, find the Positioned.fill that renders CameraPreview.
   Replace it with:
     Positioned.fill(
       child: _capturedPath != null
         ? Image.file(File(_capturedPath!), fit: BoxFit.cover)
         : Center(
             child: AspectRatio(
               aspectRatio: _cam!.value.aspectRatio,
               child: CameraPreview(_cam!),
             ),
           ),
     )
   The AspectRatio widget preserves the camera's native sensor ratio so it
   doesn't stretch to fill the screen. Center keeps it horizontally centered.
   Condition stays: only render if (_cam != null && _cam!.value.isInitialized && _isDark).

4. REMOVE REDUNDANT INPUT FROM CAMERA FAIL STATE (ingredient_entry_screen.dart — P2):
   In _cameraContent(), find this block:
     if (!_scanning && _capturedPath != null) ...[
       _addRow(dark: true),
       const SizedBox(height: 8),
     ],
   DELETE this entire block. The _addRow field in camera mode is redundant — 
   the "Type Instead" button in the failure chip panel already handles this.
   _addRow(dark: false) remains in _typeContent() only.

5. FIX BLACK SCREEN ON BACK — USE PUSH NOT PUSHREPLACEMENT (ingredient_entry_screen.dart — P1):
   In _findRecipes(), find:
     Navigator.pushReplacement(context, AppTheme.zoomIn(RecipeResultsScreen(ingredients: _ingredients)));
   Change to:
     Navigator.push(context, AppTheme.zoomIn(RecipeResultsScreen(ingredients: _ingredients)));
   This keeps IngredientEntryScreen in the stack so back from RecipeResults
   returns to scan with all ingredients still there.

6. BROWSE RECIPES BUTTON — OPEN RECIPE GRID (favorites_screen.dart — P2):
   In the empty state, find:
     onTap: () => MainShell.switchTab(0),
   Change to:
     onTap: () => Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: []))),
   Add import at top: import 'recipe_results_screen.dart';
   This opens the full recipe browse/grid screen with all recipes and filters,
   which is what "Browse Recipes" should actually do.

7. TDEE CALCULATE — SHOW ERROR IF API FAILS (onboarding_goals_screen.dart — P1):
   In _calculate(), find the catch block:
     } catch (_) {
       if (mounted) setState(() => _loading = false);
     }
   Replace with:
     } catch (e) {
       if (mounted) {
         setState(() => _loading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Could not calculate TDEE. Check your connection and try again.',
               style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
           backgroundColor: AppTheme.red,
           behavior: SnackBarBehavior.floating,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
         ));
       }
     }

After all fixes:
- Run flutter analyze — must be 0 issues
- List all files changed
- Update TASKS.md session log and bug queue statuses
- The OpenRouter key update is a manual step for Marco — document it clearly
```

---

### SESSION N — Full Backend Audit (All Endpoints, Logic, Security, Edge Cases)
**Files:** All `backend/routes/*.py`, `database.py`, `app.py`
**Goal:** Every endpoint must be verified correct, secure, and returning the right shape. No silent failures. No missing guards. All edge cases handled.

```
You are doing a full backend audit of Plately V2. Read MEMORY.md, SKILLS.md, TASKS.md first.

AUDIT SCOPE — check every single one of these:

ENDPOINT CONTRACT AUDIT:
For each endpoint, verify:
a) Input validation — all required fields checked, wrong types handled
b) Response shape — always {"status":"ok","data":...} or {"status":"error","message":...}
c) DB errors caught and returned as 500, not unhandled exceptions
d) user_id guard on all personal data endpoints (history, favorites, goals)
e) No endpoint returns raw Python exceptions to the client

ENDPOINTS TO AUDIT:
1. POST /api/scan
   - Validate image_base64 is present and valid base64
   - Check all 3 model fallbacks work (gemma-4-31b → gemma-4-26b → llama)
   - Verify ingredient matching logic returns correct results
   - Test with empty image, oversized image, non-food image

2. POST /api/recipes
   - Validate ingredients list (not empty, not >15 items)
   - Check DB cache hit/miss logic (1hr TTL)
   - Verify prefs validation (cal_goal, protein_goal, pref_* booleans)
   - Verify response includes all fields Flutter expects: id, name, cook_time,
     calories, protein, difficulty, tags, image_url, cost_php, ingredients

3. GET /api/recipe/<id>
   - Verify 404 returned for unknown id (not 500)
   - Confirm ingredients list is included in response
   - Check nutrition data included

4. POST /api/chat
   - Test with new OpenRouter key (after Marco updates Railway)
   - Verify rate limit works per user_id
   - Test history trimming logic (>6 messages)
   - Verify both MODEL_PRIMARY and MODEL_FALLBACK actually work

5. POST /api/goals
   - Validate weight/height/age/sex/goal all required
   - Verify Mifflin-St Jeor formula is correct for both male/female
   - Verify activity multiplier applied for goal (lose/maintain/gain)
   - Verify response: {calorie_target, protein_target}

6. GET /api/favorites?user_id=X
   - Verify user_id required (400 if missing)
   - Verify returns all recipe fields Flutter needs
   - Test with unknown user_id (returns empty array, not error)

7. POST /api/favorites
   - Verify duplicate save doesn't error (idempotent)
   - Verify user_id required

8. DELETE /api/favorites/<id>?user_id=X
   - Verify user_id guard
   - Verify 404 for unknown id

9. GET /api/history?user_id=X
   - Verify user_id required
   - Verify timestamps returned in ISO format
   - Verify grouped by date correctly

10. POST /api/history
    - Verify all fields: user_id, recipe_id, recipe_name, calories_logged, protein_logged
    - Verify defaults for optional fields

11. GET /api/history/stats?user_id=X
    - Verify returns: total_sessions, total_recipes, sessions_this_week
    - Verify streak calculation is correct

12. GET /api/history/daily?user_id=X&date=YYYY-MM-DD
    - Verify date format validation
    - Verify returns: calories_logged, protein_logged for that date

13. DELETE /api/history/<id>?user_id=X
    - Verify user_id guard
    - Verify only deletes entries belonging to that user_id

14. DELETE /api/history?user_id=X
    - Verify user_id guard
    - Verify clears ALL entries for that user only

15. GET /api/health
    - Verify returns {"status":"ok"} and DB connection check

ADDITIONAL CHECKS:
- CORS headers present on all responses
- Rate limiting configured correctly (not too aggressive for mobile)
- No N+1 queries in recipes or history endpoints
- All SQL uses PLACEHOLDER (never f-string values)
- Error logging is consistent (logger.error not print)
- gunicorn worker count appropriate for Railway free tier (2 workers max)

For each issue found:
- State the file + line + what's wrong
- Output the fixed code
- Explain the impact if unfixed

After audit:
- Output a PASS/FAIL table for all 15 endpoints
- List all fixes applied
- Update TASKS.md session log
```

---
**Files:** `login_screen.dart`, `signup_screen.dart`, `onboarding_goals_screen.dart`, `routes/chat.py`, `ingredient_entry_screen.dart`, `favorites_screen.dart`
**Root causes identified:**
- Google Sign-In: OAuth client ID mismatch on release build. SHA-1 is registered but the google-services.json OAuth client may be missing the release client entry, or the Android OAuth client in Google Cloud Console is not configured for the release package.
- TDEE Calculate: `_calculate()` calls the API and updates `_calGoal`/`_proteinGoal` in state but the UI widget showing the target values may be reading from a different source (e.g. SharedPreferences loaded at init, not from state). The banner/display needs to read directly from the state variables, not cached prefs.
- AI Chat 502: OpenRouter free tier may be rate-limited or the gemma-4-31b model is unavailable. Switch to `google/gemma-3-12b-it:free` as primary with `meta-llama/llama-3.3-8b-instruct:free` as fallback. Also add better error message in Flutter UI — instead of generic "AI Service Error", show "AI is busy, try again in a moment."
- Camera white screen: `CameraPreview` on physical Android devices fails when the controller is not fully initialized before being added to the widget tree. Need to gate render on `_cam!.value.isInitialized` not just `_camReady` bool. Also ensure `dispose()` properly calls `_cam?.dispose()`.
- Favorites empty state: current empty state is a plain `Column` with `Icon` + `Text` — looks unfinished. Replace with a proper illustrated SVG/custom painted empty state card matching Plately design system.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES TO CHANGE:
- lib/screens/login_screen.dart
- lib/screens/signup_screen.dart
- lib/screens/onboarding_goals_screen.dart
- backend/routes/chat.py
- lib/screens/ingredient_entry_screen.dart
- lib/screens/favorites_screen.dart

FIXES NEEDED:

1. GOOGLE SIGN-IN RELEASE FIX (login_screen.dart + signup_screen.dart — P1):
   The release APK Google Sign-In fails with an OAuth error. The SHA-1 is already
   registered in Firebase. The likely cause is that google-services.json is missing
   the release OAuth web client ID, OR the GoogleSignIn() call is missing the
   clientId parameter on Android.
   FIX:
   a) In both login_screen.dart and signup_screen.dart, find the GoogleSignIn()
      instantiation. Add explicit serverClientId from google-services.json:
      GoogleSignIn(scopes: ['email'], serverClientId: 'YOUR_WEB_CLIENT_ID')
      The web client ID is in google-services.json under
      oauth_client where client_type == 3. Extract and hardcode it.
   b) In _handleGoogleSignIn(), add a try/catch that catches PlatformException
      and shows a SnackBar with the error code so we can debug further if needed.
   c) Read google-services.json via Desktop Commander to find the correct
      web client ID and use it in both files.

2. TDEE CALCULATE NOT REFLECTING (onboarding_goals_screen.dart — P1):
   After _calculate() runs and sets _calGoal/_proteinGoal in setState(),
   the displayed targets must update immediately in the UI.
   FIX:
   a) Find where calorie and protein targets are displayed in the screen.
      They must reference _calGoal and _proteinGoal state variables directly —
      NOT values loaded from SharedPreferences at init.
   b) Add a visible result banner that appears after Calculate is tapped:
      AnimatedSwitcher wrapping a green Container that shows:
      "Daily Target: $_calGoal kcal · $_proteinGoal g protein"
      Only visible when _calGoal != 2200 || _proteinGoal != 120.
   c) Make sure the Calculate button has a loading state (_calculating bool)
      that shows a CircularProgressIndicator inside the button while waiting.
   d) Verify _save() uses _calGoal and _proteinGoal (not hardcoded defaults).
   Output complete replacement file for onboarding_goals_screen.dart.

3. AI CHAT — SWITCH MODEL + BETTER ERROR UI (chat.py + ai_chat_screen.dart — P1):
   BACKEND (chat.py):
   - Change primary model from google/gemma-4-31b-it:free to google/gemma-3-12b-it:free
   - Add fallback: if primary returns non-200 or empty, retry with
     meta-llama/llama-3.3-8b-instruct:free
   - Add detailed error logging: log the full response body when status != 200
   - Return {"status": "error", "message": "AI is busy, please try again"} on failure
     instead of a generic 500.

   FRONTEND (ai_chat_screen.dart):
   - Change the red error bubble text from "AI Service Error" to the actual
     message returned in the error response body if available.
   - If message contains "busy" or "unavailable", show:
     "AI Chef is busy right now — tap to retry"
     with a retry icon button that resends the last message.
   Output complete replacement files for both.

4. CAMERA WHITE SCREEN — PROPER INIT GATE (ingredient_entry_screen.dart — P1):
   Root cause: _camReady is set to true in setState() after initializeController()
   completes, but CameraPreview is rendered before the controller's internal
   value.isInitialized is true on some devices.
   FIX:
   a) Replace the _camReady bool gate with a direct check:
      (_cam != null && _cam!.value.isInitialized)
      Use this everywhere CameraPreview is conditionally rendered.
   b) In _initCamera(), after await _cam!.initialize(), add:
      if (!_cam!.value.isInitialized) return; // extra safety guard
   c) In dispose(), ensure:
      await _cam?.dispose();
      _cam = null;
      This prevents "CameraController was used after being disposed" crashes.
   d) Wrap the CameraPreview in a direct Positioned.fill with no AnimatedOpacity:
      Positioned.fill(
        child: (_cam != null && _cam!.value.isInitialized)
          ? CameraPreview(_cam!)
          : const SizedBox.shrink(),
      )
   Output complete replacement file for ingredient_entry_screen.dart.

5. FAVORITES EMPTY STATE REDESIGN (favorites_screen.dart — P3):
   Replace the plain icon + text empty state with a polished card:
   - Centered Column inside a rounded Container (radius 20, AppTheme.cardBg)
   - A large custom SVG-style illustration: a plate with a heart on it, drawn
     using Flutter's CustomPaint or a Stack of Icons — no external assets needed.
     Use LucideIcons.utensils (size 48, color AppTheme.primaryDark.withValues(alpha:0.15))
     as the base, overlaid with LucideIcons.heart (size 24, AppTheme.red) offset
     to bottom-right of the utensils icon.
   - Title: "No saved recipes yet" — 16px DM Sans w700, AppTheme.textPrimary(context)
   - Subtitle: "Tap the heart on any recipe to save it here"
     13px DM Sans w400, AppTheme.textMuted(context)
   - A "Browse Recipes" button: ElevatedButton with AppTheme.primaryDark bg,
     onPressed: () => MainShell.switchTab(0) to go to Home.
   Output complete replacement file for favorites_screen.dart.

After all fixes:
- Run flutter analyze — must be 0 issues
- List all files changed
- Update TASKS.md, MEMORY.md session log
```
**Files:** `android/app/src/main/res/` (icon), `login_screen.dart`, `signup_screen.dart`, `onboarding_goals_screen.dart`
**Root causes identified:**
- App icon: `plately_logo.dart` `_RingMarkPainter` uses `showBackground=true` on dark → dark teal gradient bg with low contrast on phone grid. Launcher icon needs a vibrant, high-contrast version.
- Google Sign-In: Firebase project likely only has Gmail OAuth scope or SHA-1 only covers debug keystore not release keystore. Both keystores must be registered in Firebase console.
- Goals TDEE: `_calculate()` in `onboarding_goals_screen.dart` calls `ApiService.setGoals()` and updates `_calGoal`/`_proteinGoal` state correctly in code — but the Calculate button may not be wired or the result card is not showing. Need to verify the button calls `_calculate()` and the result is displayed visually before `_save()`.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES: android/app/src/main/res/ icons, login_screen.dart, signup_screen.dart, onboarding_goals_screen.dart

FIXES NEEDED:

1. APP LAUNCHER ICON — VIBRANT REDESIGN:
   The current launcher icon uses a dark teal gradient background that looks dull
   on the Android home screen next to colourful apps like Spotify.
   Use the SAME ring-mark design from PlatelyLogo but with a vivid background:
   - Background: bright gradient from AppTheme.green (#76CC4F) to AppTheme.primaryDark (#043B3C),
     top-left to bottom-right, with rounded corners (radius ~22% of size).
   - Ring track: white with alpha 0.25
   - Green arc: white (so it pops on the green bg)
   - Accent arc: white with alpha 0.90
   - Centre dot: white outer, green inner
   This makes the icon instantly recognisable and vibrant on any wallpaper.
   Generate the icon programmatically via a Flutter script or update the
   existing adaptive icon XML in android/app/src/main/res/.
   The foreground layer should be the ring mark centred on transparent bg.
   The background layer should be the green-to-teal gradient.
   Also update ic_launcher.png files in all mipmap folders (use a script).

2. GOOGLE SIGN-IN — RELEASE KEYSTORE SHA-1:
   The release APK uses upload-keystore.jks but only the debug SHA-1 may be
   registered in Firebase. This causes Google Sign-In to fail on release builds.
   FIX: Print the release SHA-1 from the keystore and add instructions for Marc
   to add it to Firebase Console → Project Settings → Android app → Add fingerprint.
   In android/app/build.gradle, verify signingConfigs.release is wired correctly.
   Output the exact SHA-1 command Marc needs to run and the exact Firebase Console
   step to add it. Do NOT change any code — this is a config fix only.

3. GOALS — VERIFY CALCULATE IS WIRED AND RESULT IS SHOWN:
   In onboarding_goals_screen.dart:
   a) The Calculate button MUST call _calculate() on tap — verify it does.
   b) After _calculate() succeeds, show a result banner ABOVE the Save button:
      Container with AppTheme.green bg, showing:
      "Daily Target: {_calGoal} kcal · {_proteinGoal}g protein"
      Only show this banner when _calGoal != 2200 || _proteinGoal != 120
      (i.e. after a successful calculation). Use AnimatedSwitcher to fade it in.
   c) _save() must use the current _calGoal/_proteinGoal values — verify it does.

Output complete replacement files for onboarding_goals_screen.dart only.
For the icon and Google auth, output instructions only (no code changes to source).
```

---

### SESSION I — Home Dark Mode + Favorites UI
**Files:** `home_screen.dart`, `widgets/activity_row.dart`, `favorites_screen.dart`, `widgets/plately_logo.dart`
**Root causes identified:**
- Home dark mode: multiple hardcoded static colors throughout `home_screen.dart` and `activity_row.dart` using `Colors.white`, `AppTheme.darkText`, `AppTheme.mutedText` instead of context-aware helpers.
- ActivityRow: `color: Colors.white` hardcoded on the card container — turns white in dark mode. Uses `const TextStyle(color: AppTheme.darkText)` — static, not dark-aware.
- Logo box: `PlatelyLogo` with `showBackground=true` renders a dark teal box in the AppBar. In dark mode this creates a visible square. Fix: always use `showBackground: false` in AppBar/header contexts; background is only for the launcher icon.
- Favorites heart: `LucideIcons.heart` (outline) vs `LucideIcons.heartFilled` (solid). When favorited, should show `heartFilled` in red — like Instagram, Spotify, every major app. Currently only color changes on an outline icon.
- Favorites search field: uses `Container + InputBorder.none` without explicit `OutlineInputBorder` — same issue as other fields.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES: home_screen.dart, widgets/activity_row.dart, favorites_screen.dart, widgets/plately_logo.dart

FIXES NEEDED:

1. ACTIVITY ROW DARK MODE (activity_row.dart — P1):
   The entire widget uses hardcoded light-mode colors. Fix every one:
   - Container color: Colors.white → AppTheme.cardBg(context)
   - Border: AppTheme.borderGray → AppTheme.border(context)
   - recipeName TextStyle: const color AppTheme.darkText → AppTheme.textPrimary(context)
   - subtitle TextStyle: const color AppTheme.mutedText → AppTheme.textMuted(context)
   - Badge bg: AppTheme.scanGreen → keep (decorative, fine in both modes)
   Remove all const from TextStyle that use static dark-text colors.

2. HOME SCREEN DARK MODE (home_screen.dart — P1):
   Audit the ENTIRE file for any hardcoded Colors.white, AppTheme.darkText,
   AppTheme.mutedText used in TextStyle inside widget build methods.
   Replace all with context-aware equivalents per SKILLS.md rules.
   Special attention to:
   - Section header labels ("Suggested For You", "Recent Activity")
   - Macro ring labels and values
   - Date label ("Today, May 12") — use AppTheme.textPrimary(context) with w700
   - Calendar day labels
   - The greeting text

3. LOGO IN APPBAR / HEADER (plately_logo.dart — P2):
   Add a named constructor or parameter `inAppBar: bool = false`.
   When inAppBar=true (or when theme=onLight and showBackground=true):
   set showBackground=false automatically so the ring mark never draws
   a background box when placed on a scaffold/card background.
   The background tile is ONLY for the launcher icon.
   In home_screen.dart AppBar, pass the correct theme variant with no background.

4. FAVORITES HEART — FILLED WHEN ACTIVE (favorites_screen.dart — P1):
   Find the heart icon in the recipe card or favorite button.
   When favorited: Icon(LucideIcons.heartFilled, color: AppTheme.red)
   When not favorited: Icon(LucideIcons.heart, color: AppTheme.iconColor(context))
   This is standard across all major apps — filled solid heart = saved.
   Also check recipe_detail_screen.dart hero favorite button — same fix.

5. FAVORITES SEARCH FIELD CORNERS (favorites_screen.dart — P1):
   Apply AppTheme.inputDecoration() to the search TextField, OR ensure the
   wrapping Container has borderRadius: BorderRadius.circular(12) AND
   Border.all(color: AppTheme.border(context)), with the TextField using
   enabledBorder: InputBorder.none and focusedBorder: InputBorder.none.

Output complete replacement files for all 4 files.
```

---

### SESSION J — Recipe Detail UX + Camera P0 + Scan UI
**Files:** `recipe_detail_screen.dart`, `ingredient_entry_screen.dart`
**Root causes identified:**
- Share sheet closes instantly: `_showShareSheet` uses `showModalBottomSheet` — it may be dismissed by `Navigator.pop(context)` running 200ms after it opens. The pop should only happen after user explicitly closes the sheet, not on a timer.
- Tab divider light mode: `_Tab` container uses `color: AppTheme.cardAltBg(context)` as the pill bg. In light mode `cardAltBg` is very close to white scaffold, so no visible border around the pill. Need an explicit `border: Border.all(color: AppTheme.border(context))` on the tab container.
- Steps tappable hint: no visual affordance. Add a small one-time hint row at the top of the steps list.
- Camera white screen: likely an Android TextureView/SurfaceView issue where `CameraPreview` is placed inside a `Stack` with `AnimatedOpacity`. On some devices the opacity animation causes a blank frame. Fix: remove `AnimatedOpacity` wrapper and use `Visibility` or direct conditional rendering.
- Scan dark mode: already partially done but chip panel, mode pill, type content need audit.
- Scan type field: `enabledBorder`/`focusedBorder` fix was applied in S45 but needs verification; also the wrapping Container must have explicit rounded corners visible in both modes.

```
You are fixing the Plately V2 Flutter app. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES: recipe_detail_screen.dart, ingredient_entry_screen.dart

FIXES NEEDED:

1. SHARE SHEET — DO NOT AUTO-DISMISS (recipe_detail_screen.dart — P2):
   Current: after _showShareSheet(), there is a Future.delayed(200ms) then Navigator.pop().
   This instantly closes the screen before the user can interact with the share sheet.
   FIX: Remove the auto Navigator.pop() entirely from _finishCooking().
   Instead, inside _showShareSheet()'s bottom sheet, add a "Done" button that calls
   Navigator.pop(context) to close the sheet, then Navigator.pop(context) again to
   go back to the previous screen. User stays in control.

2. TAB DIVIDER LIGHT MODE (recipe_detail_screen.dart — P2):
   The tab switcher Container (height 44, borderRadius 14) uses only
   color: AppTheme.cardAltBg(context) with no border.
   Add: border: Border.all(color: AppTheme.border(context), width: 1)
   to the BoxDecoration so it's visible in light mode.

3. STEPS TAPPABLE HINT (recipe_detail_screen.dart — P2):
   At the top of _buildSteps(), before the List.generate, add one small hint row:
   Row with Icon(LucideIcons.handPointing, size: 12) and Text "Tap a step to mark it done"
   Style: AppTheme.textMuted(context), 11px DM Sans.
   Only show this hint if _completedSteps.isEmpty (disappears once user taps first step).

4. CAMERA WHITE SCREEN P0 (ingredient_entry_screen.dart — P0):
   Root cause: CameraPreview is wrapped in AnimatedOpacity which causes blank frames
   on some Android devices (TextureView rendering issue with opacity animations).
   FIX: Replace AnimatedOpacity wrapping CameraPreview with a direct conditional:
   if (_camReady && _cam != null && _isDark) CameraPreview(_cam!)
   else if (_camReady && _cam != null) CameraPreview(_cam!) with Opacity(0) via
   a simpler IgnorePointer + Offstage approach.
   Simplest correct fix: remove AnimatedOpacity entirely. Use:
     if (_camReady && _cam != null)
       Positioned.fill(child: _capturedPath != null
         ? Image.file(File(_capturedPath!), fit: BoxFit.cover)
         : CameraPreview(_cam!))
   Only show it when _isDark (camera mode + ready). Otherwise keep it off the tree.

5. SCAN PAGE DARK MODE AUDIT (ingredient_entry_screen.dart — P1):
   Go through every widget in _cameraContent(), _typeContent(), _modePill(),
   _topBar(), _chipPanel(), _addRow():
   - Any Colors.white used as TEXT color → replace with context-aware or keep white
     only when explicitly on dark bg (camera mode).
   - _typeContent empty state: ensure text uses AppTheme.textPrimary/textMuted.
   - _addRow when dark=false: verify corners visible, border visible, hint text visible.

6. SCAN TYPE FIELD (ingredient_entry_screen.dart — P1):
   _addRow(dark: false) TextField must use:
   border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none
   The wrapping Container must have borderRadius: BorderRadius.circular(16) AND
   Border.all(color: AppTheme.border(context)) — verify both are present.

Output complete replacement files for both files.
```

---

### SESSION K — Profile Redesign + Global UI Audit + Backend Verification
**Files:** `profile_screen.dart`, all screens for audit, backend routes for live testing
**Root causes identified:**
- Profile dietary prefs: using `Wrap` of chips — looks cluttered. Best practice (Spotify, MyFitnessPal) uses toggle rows with icon + label + switch/checkmark on right. Each pref on its own full-width row.
- Profile theme picker: `_themeRow()` with icon+label+checkmark — needs audit for dark mode visibility.
- Global UI audit: after all fixes, do a pass checking typography hierarchy, button tap targets (min 44px), color contrast on both modes.
- Backend: call each endpoint directly and verify response shape matches what Flutter expects.

```
You are doing a final polish + verification pass on Plately V2. Read MEMORY.md, SKILLS.md, TASKS.md first.

PART 1 — PROFILE DIETARY PREFS REDESIGN (profile_screen.dart):

Replace the Wrap of chip buttons with full-width toggle rows. Each dietary pref
gets its own row inside the dietary card:

Row layout: [Icon] [Label + subtitle] [Spacer] [Animated toggle indicator]
- Icon: small, AppTheme.primaryDark or AppTheme.green when active
- Label: 14px DM Sans w600, AppTheme.textPrimary(context)
- Subtitle: 12px DM Sans, AppTheme.textMuted(context) — brief description of the pref
- Toggle: use a custom AnimatedContainer pill (48x26) — teal when ON, grey when OFF
  with a white circle that slides left/right. NO Flutter Switch widget.

Prefs and their subtitles:
- Vegetarian | "No meat or fish"
- High-Protein | "Prioritise 30g+ protein per meal"
- Gluten-Free | "Exclude gluten-containing ingredients"
- Dairy-Free | "Exclude dairy products"

Keep the exact same toggle logic (pref_gluten=false means active, etc.) per SKILLS.md.

PART 2 — GLOBAL UI AUDIT (all screens):

Go through each screen and fix any remaining violations of these rules:
1. CONTRAST: Every text element must be legible in both light and dark mode.
   No static AppTheme.darkText or AppTheme.mutedText in widget bodies.
2. BUTTON SIZES: Every tappable element min 44×44px.
3. FONT HIERARCHY: Screen titles 18-20px w800, section labels 15px w700,
   body 14px w500, captions 12px w400. Verify each screen follows this.
4. BORDER RADIUS: All input fields radius 12, cards radius 16, large cards radius 20.
5. EMPTY STATES: Every list/grid has a proper empty state with icon + message.

Only output files where you actually find and fix violations.

PART 3 — BACKEND LIVE API VERIFICATION:

Test each endpoint against https://plately-production.up.railway.app using curl
or Python requests. Verify:
- GET  /api/health → {"status":"ok"}
- POST /api/goals with sample payload → returns calories + protein
- POST /api/recipes with sample payload → returns array of recipes
- POST /api/chat with sample message → returns AI reply
- POST /api/scan with tiny base64 image → returns ingredients or error (not 500)
- GET  /api/history?user_id=test → returns array
- GET  /api/history/stats?user_id=test → returns total_sessions etc.

For any endpoint that returns an error or unexpected shape, output the fix
for the relevant backend route file.

Output: fixed profile_screen.dart, any other screens with actual violations found,
and any backend route fixes needed.
```

---

## PRE-DEPLOY CHECKLIST

### Marco (backend):
- [x] Railway backend live ✅
- [x] Neon DB connected + seeded ✅
- [x] cron-job.org keepalive ✅
- [x] history.py DELETE guards ✅
- [x] app.py CORS uses ALLOWED_ORIGINS env var ✅
- [x] recipes.py prefs validation ✅
- [x] chat.py error logging + OpenRouter guards ✅
- [x] ALLOWED_ORIGINS set in Railway ✅ (kept as * — correct for mobile)

### Marc (frontend):
- [x] Keystore path fixed ✅
- [x] flutter analyze → 0 issues ✅
- [x] Release APK built ✅
- [x] Committed + pushed fbe8545 ✅
- [x] Firebase App Distribution testers added ✅
- [ ] Run Sessions H → K
- [ ] Add release SHA-1 to Firebase Console (from Session H instructions)
- [ ] Rebuild APK after H → K done

---

## SESSION LOG

| Session | What Was Done | Key Files |
|---------|---------------|-----------|
| 1–31 | See prior TASKS.md | — |
| 32 | Full source audit — 6 fix queues written | TASKS.md |
| 33 | history.py crash fix, camera permission flow, profile theme toggle, icon fixes | history.py, ingredient_entry_screen.dart, profile_screen.dart, ai_chat_screen.dart |
| 34 | chat.py Gemma fix, camera error overlay, dark mode: history/profile/favorites | chat.py, ingredient_entry_screen.dart, history_screen.dart, profile_screen.dart |
| 35 | Dark mode fixes: home, onboarding, profile, ai_chat, recipe_detail, pantry, shopping | All screens |
| 36 | Deleted dead _buildMacroRings, AlertDialog dCtx, _finishCooking mounted checks, dietary toggle, retake, calendar | home_screen.dart, history_screen.dart, recipe_detail_screen.dart, profile_screen.dart |
| 37 | Dark mode regressions across all screens | All screens |
| 38 | Streak reset, Shopee fallback, pull-to-refresh sync, _loadHistory try/catch | user_prefs_service.dart, recipe_detail_screen.dart, home_screen.dart, shopping_list_screen.dart |
| 39 | Backend hardening: DELETE guards, CORS env var, prefs validation | history.py, app.py, recipes.py |
| 40 | flutter analyze 0 issues, keystore fix, APK built | All files |
| 41 | QA test plan written (111 TCs) | TASKS.md |
| 42 | QA observations logged. 7 fix sessions (A–G) written | TASKS.md |
| 43 | Session G: inputDecoration helper, login/signup dark mode, home, onboarding, ai_chat, shimmer, chat.py | Multiple files |
| 44 | Full source audit — Sessions A,B,E,F verified done. Only C+D remained | TASKS.md, MEMORY.md, SKILLS.md |
| 45 | Sessions C+D completed. Pushed fbe8545. New QA round from device. Sessions H,I,J,K written | TASKS.md |
| I | Session I: home borderGray fix, RecipeCard isFavorited heart badge, _Stat context-aware color, flutter analyze 0 | home_screen.dart, recipe_card.dart, favorites_screen.dart |
| J | Session J: recipe_detail share drag-handle fix, _Chip/PillTab context colors, flutter analyze 0; all other J items verified already correct | recipe_detail_screen.dart, ingredient_entry_screen.dart |
| K | Session K: live API verification — all endpoints passing; OpenRouter gemma-3-27b permanently gone, updated to gemma-4-31b across chat.py/recipes.py/scan.py | chat.py, recipes.py, scan.py |
| QA L1 | Backend live test suite (28/32 pass) + auth flow code audit. 1 real bug: /api/chat 502 (model not deployed to Railway). Auth code fully clean. L2–L4 can proceed. | qa_l1_test.py, TASKS.md |
| QA L2 Fixes | _formatTimestamp toLocal() fix in home_screen.dart; RecipeCard isFavorited uses Icons.favorite (filled); recipe_detail verified correct; flutter analyze 0 | home_screen.dart, recipe_card.dart |
| QA L3 | History + AI Chat + Pantry + Shopping + Scan audit complete. 1 P2 bug: pantry key not UID-namespaced. All critical flows pass. | TASKS.md |
| QA L4 Fixes | Cook Again button added to _HistoryRow (shows when recipe_id > 0); TASKS/MEMORY/SKILLS updated; flutter analyze 0; READY TO COMMIT + PUSH | history_screen.dart, TASKS.md, MEMORY.md, SKILLS.md |
| L (setup) | APK deployed + device tested. 5 bugs found: Google Sign-In failure, TDEE not reflecting, AI chat service error, camera white screen, favorites empty state. Session L prompt written. | TASKS.md |
| L (fixes) | auth_service.dart: serverClientId added; chat.py: model switched to llama-3.3-8b + mistral fallback; ingredient_entry_screen.dart: camera isInitialized gate; favorites_screen.dart: empty state redesign. flutter analyze 0. APK rebuilt + Firebase distributed. | auth_service.dart, chat.py, ingredient_entry_screen.dart, favorites_screen.dart |
| M (setup) | Device test after L deploy. 6 new bugs: Google Sign-In still failing, AI all models failed (key exhausted), camera stretched, redundant input field, black screen on back, Browse Recipes goes to Home. Session M + N prompts written. | TASKS.md |

---

## BACKLOG (post v1.0)
- [ ] Home Recent Activity: show "couldn't load" on network error
- [ ] Shopping list → share as plain text (WhatsApp/SMS)
- [ ] Recipe rating / cook count
- [ ] Custom recipe notes per-user
- [ ] Ingredient substitution AI ("I don't have X")
- [ ] Sentry error monitoring (free tier)
- [ ] Pantry header badge: split "X in fridge / Y always stocked"
- [ ] AI Chat: show "history trimmed" badge on sessions > 30 messages
- [ ] Recipe detail: Cook Again pre-scales to last used serving size
