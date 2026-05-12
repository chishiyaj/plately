# PLATELY V2 — QA SESSION L4: Profile + Global Checks + Final Verdict
> Paste alongside MEMORY.md, SKILLS.md, TASKS.md.
> Scope: Profile screen + cross-cutting checks + final release verdict.
> This is the last QA session. Output the final go/no-go.

---

## YOUR ROLE
Senior QA engineer. Read source files via Desktop Commander.
Assume L1–L3 are done. This session closes the audit.

---

## STEP 1 — READ THESE FILES
```
lib/screens/profile_screen.dart
lib/main.dart
lib/app_theme.dart
lib/widgets/plately_logo.dart
lib/widgets/plately_share_card.dart
lib/services/user_prefs_service.dart
```

---

## STEP 2 — PROFILE SCREEN AUDIT

- [ ] Avatar shows initials or photo correctly
- [ ] Stats (recipes cooked, streak, favorites count) pull from correct sources
- [ ] Goals card shows current _calGoal + _proteinGoal from SharedPreferences
- [ ] Dietary prefs — toggle rows (not chip Wrap):
  - [ ] Vegetarian row: toggle ON/OFF saves pref_veg correctly
  - [ ] High-Protein row: toggle saves pref_hipro correctly; explanation text shown
  - [ ] Gluten-Free row: pref_gluten=false means ACTIVE (restriction ON)
  - [ ] Dairy-Free row: pref_dairy=false means ACTIVE (restriction ON)
  - [ ] Animated pill slides correctly (not Flutter Switch widget)
- [ ] Theme picker: Light/Dark/System rows with checkmark on active
- [ ] Theme change: themeNotifier.value updated + persisted to SharedPreferences
- [ ] Settings: package_info_plus shows real version number
- [ ] Logout: clears auth state, routes to LoginScreen
- [ ] No static AppTheme.darkText / AppTheme.mutedText in TextStyle in widget bodies

---

## STEP 3 — GLOBAL CROSS-CUTTING CHECKS

### Navigation
- [ ] Bottom nav indices correct: 0=Home, 1=Favorites, 2=AiChat, 3=Profile
- [ ] Scan FAB: LucideIcons.scanLine, no label, clean circle
- [ ] MainShell.switchTab(n) works from RecipeDetail Ask AI FAB
- [ ] Back navigation never strands user on black screen

### Dark Mode
- [ ] Toggle from Profile → entire app switches instantly via themeNotifier
- [ ] No screen has a white flash or incorrect background on switch
- [ ] PlatelyLogo: onDark variant used when AppTheme.isDark(context) is true
- [ ] PlatelyLogo: never shows background box in AppBar/scaffold contexts

### State & Persistence
- [ ] All SharedPreferences keys are uid-namespaced (not global keys)
- [ ] Daily macro resets on new day (not on app restart within same day)
- [ ] Streak persists across cold starts

### Code Quality (run flutter analyze)
- [ ] 0 issues — no static color violations, no deprecated widgets
- [ ] No WillPopScope (use PopScope)
- [ ] No withOpacity on const colors (use withValues(alpha:))
- [ ] No LucideIcons.alertCircle (use circleAlert)

### Notifications
- [ ] Cook-done one-shot fires after Finish Cooking
- [ ] 5 dynamic scheduled notifications set on app start
- [ ] Notification permissions requested correctly on Android

---

## STEP 4 — CONSOLIDATE ALL L1–L4 FINDINGS

List every 🔴 bug found across all 4 sessions here in one table:

| Priority | Screen | Bug | Root Cause | Fix Needed |
|----------|--------|-----|------------|------------|
| P0/P1/P2/P3 | ... | ... | ... | ... |

---

## FINAL VERDICT

### ✅ PASSING (summarise)

### ⚠️ NEEDS ATTENTION (non-blocking, note for backlog)

### 🔴 BLOCKERS (P0/P1 only)

---

### RELEASE DECISION
Choose one:

**READY TO RELEASE ✅**
> No P0/P1 bugs found. Marc can rebuild APK and distribute.

**NEEDS FIXES BEFORE RELEASE 🔴**
> List P0/P1 bugs. Then output a SESSION L-FIX prompt below:

---

## SESSION L-FIX PROMPT (only output if bugs found)

```
You are fixing pre-release bugs in Plately V2. Read MEMORY.md, SKILLS.md, TASKS.md first.

FILES: [list only files that need changes]

FIXES NEEDED:
[one section per bug, with root cause and exact fix]

Output complete replacement files only. No partial implementations.
```
