# PLATELY V2 — QA SESSION L2: Home + Recipes + Favorites
> Paste alongside MEMORY.md, SKILLS.md, TASKS.md.
> Scope: Home screen, Recipe Results, Recipe Detail, Favorites.
> Keep output SHORT — one line per check. Stop after Report.

---

## YOUR ROLE
Senior QA engineer. Read source files via Desktop Commander.
Output pass/fail tables. Do NOT fix — report only.

---

## STEP 1 — READ THESE FILES
```
lib/screens/home_screen.dart
lib/screens/recipe_results_screen.dart
lib/screens/recipe_detail_screen.dart
lib/screens/favorites_screen.dart
lib/widgets/recipe_card.dart
lib/widgets/activity_row.dart
```

---

## STEP 2 — HOME SCREEN AUDIT

- [ ] Greeting uses uid-namespaced username from SharedPreferences
- [ ] Macro rings read from /api/history/daily (not hardcoded)
- [ ] Pull-to-refresh calls _loadDailyMacros() — re-syncs from API
- [ ] Streak: UserPrefsService.resetStreakIfExpired() called in _loadPrefs()
- [ ] Streak: UserPrefsService.saveLastCookDate() called after Finish Cooking
- [ ] Calendar widget: correct day highlighted, Mon–Sun layout
- [ ] Suggested recipes: tapping navigates to RecipeDetail with correct id
- [ ] Recent Activity: ActivityRow uses AppTheme.cardBg(context) — not Colors.white
- [ ] Recent Activity: timestamps use .toLocal() before diff calculation
- [ ] Recent Activity: entry tap opens correct recipe (passes recipe_id not index)
- [ ] No static AppTheme.darkText / AppTheme.mutedText in TextStyle in widget bodies
- [ ] No hardcoded hex colors

---

## STEP 3 — RECIPE RESULTS AUDIT

- [ ] Shimmer shows during load; shimmer widget is dark-mode-aware
- [ ] Filters (Asian/Filipino/etc.) send correct tag to /api/recipes
- [ ] Search bar filters locally or re-queries correctly
- [ ] Error state shown on API failure (not blank screen)
- [ ] Offline banner present
- [ ] RecipeCard: heart icon is LucideIcons.heartFilled (solid red) when favorited
- [ ] RecipeCard: heart icon is LucideIcons.heart (outline) when not favorited
- [ ] Tapping card passes correct recipe object to RecipeDetail

---

## STEP 4 — RECIPE DETAIL AUDIT

- [ ] Ingredients tab: all ingredients shown with scaled quantities
- [ ] Serving scaler: changing servings scales all ingredient amounts proportionally
- [ ] Steps tab: tapping a step marks it done with visual feedback
- [ ] Steps hint row: visible until first step tapped, then disappears
- [ ] Tab switcher container has Border.all(AppTheme.border(context)) — visible in light mode
- [ ] Nutrition card: calories + protein from API (not hardcoded)
- [ ] Ask AI FAB: opens AiChat screen with recipe context as initialPrompt
- [ ] Favorite button: toggles filled/outline, persists via /api/favorites
- [ ] Share card: Done button closes sheet then pops screen (no auto-dismiss timer)
- [ ] Finish Cooking: posts to /api/history with calories_logged + protein_logged
- [ ] Finish Cooking: triggers cook-done notification (one-shot)
- [ ] All async gaps have mounted checks

---

## STEP 5 — FAVORITES AUDIT

- [ ] Loads from /api/favorites with current user_id
- [ ] Search filters by recipe name
- [ ] Category filter chips work
- [ ] Empty state shown when list is empty
- [ ] Unfavoriting calls DELETE /api/favorites/<id> and removes from list
- [ ] AppTheme.inputDecoration() used on search field

---

## REPORT FORMAT

### Home Screen
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Recipe Results
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Recipe Detail
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Favorites
| Check | Pass/Fail | Note |
|-------|-----------|------|

### 🔴 Bugs Found
- Screen | What's wrong | Root cause

### Verdict for L2
- PASS — proceed to L3
- FAIL — list blockers
