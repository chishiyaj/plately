# PLATELY V2 — QA SESSION L3: History + AI Chat + Pantry + Shopping + Scan
> Paste alongside MEMORY.md, SKILLS.md, TASKS.md.
> Scope: History, AI Chat, Pantry, Shopping List, Ingredient Entry (Scan).
> Keep output SHORT — one line per check. Stop after Report.

---

## YOUR ROLE
Senior QA engineer. Read source files via Desktop Commander.
Output pass/fail tables. Do NOT fix — report only.

---

## STEP 1 — READ THESE FILES
```
lib/screens/history_screen.dart
lib/screens/ai_chat_screen.dart
lib/screens/pantry_screen.dart
lib/screens/shopping_list_screen.dart
lib/screens/ingredient_entry_screen.dart
```

---

## STEP 2 — HISTORY SCREEN AUDIT

- [ ] Stats card reads from /api/history/stats (not hardcoded)
- [ ] Weekly calendar: Mon–Sun bars, correct week highlighted
- [ ] Prev/next week navigation works; forward arrow blocked at current week
- [ ] Timestamps: uses .toLocal() before diff; format is "Today 2:30 PM" / "Yesterday" / weekday / "May 3"
- [ ] 12-hour AM/PM format — no GMT, no seconds
- [ ] Entry tap: opens RecipeDetail with correct recipe_id (not list index)
- [ ] Delete single: AlertDialog uses dCtx not context; calls DELETE /api/history/<id>?user_id=
- [ ] Clear all: AlertDialog uses dCtx; calls DELETE /api/history?user_id=
- [ ] Cook Again: navigates to RecipeDetail correctly
- [ ] _loadHistory() wrapped in try/catch — no unhandled crash on API failure
- [ ] No static color violations

---

## STEP 3 — AI CHAT AUDIT

- [ ] Quick chips send correct pre-written prompts
- [ ] User message appears immediately (optimistic UI)
- [ ] API call to /api/chat with full history array
- [ ] Response rendered as Markdown (flutter_markdown)
- [ ] Error response (starts with "ERROR:") shows red bubble with LucideIcons.circleAlert
- [ ] initialPrompt from RecipeDetail pre-fills and sends on open
- [ ] Dark mode: welcome subtitle uses AppTheme.textMuted(context) — not static

---

## STEP 4 — PANTRY AUDIT

- [ ] Add item: all 4 fields (name, quantity, unit, always-stocked) save correctly
- [ ] Items persist across restarts (SharedPreferences, uid-namespaced)
- [ ] Always-stocked toggle saves and restores correctly
- [ ] Delete item removes from list and prefs
- [ ] All TextFields use AppTheme.inputDecoration() — no InputBorder.none + manual Container
- [ ] No static color violations

---

## STEP 5 — SHOPPING LIST AUDIT

- [ ] Auto-populates from last cooked recipe's ingredients
- [ ] Pantry items (always-stocked) are crossed out / excluded
- [ ] Shopee deep-link: url_launcher opens shopee.ph in browser
- [ ] Fallback: copies SINGLE item name only (not full list)
- [ ] No static color violations

---

## STEP 6 — INGREDIENT ENTRY (SCAN) AUDIT

- [ ] Camera tab: permission_handler requests camera permission on first open
- [ ] Camera permission denied: error overlay shown, retry button works
- [ ] Viewfinder: CameraPreview is Positioned.fill — no AnimatedOpacity wrapper
- [ ] Capture: sends base64 to /api/scan, shows loading spinner
- [ ] Scan result: ingredients appear as chips
- [ ] Retake button: clears scan state only — does NOT clear typed ingredients (_ingredients list)
- [ ] Type tab: typing + Add button creates ingredient chips
- [ ] Chip tap removes ingredient
- [ ] Get Recipes button: disabled when 0 ingredients, navigates to RecipeResults when >0
- [ ] Dark mode: type field has borderRadius 16 + AppTheme.border(context) visible
- [ ] _PillTab and chip colors use context-aware colors (not static)
- [ ] Lifecycle retry: if camera paused (app backgrounded), resumes on return

---

## REPORT FORMAT

### History
| Check | Pass/Fail | Note |
|-------|-----------|------|

### AI Chat
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Pantry
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Shopping List
| Check | Pass/Fail | Note |
|-------|-----------|------|

### Scan / Ingredient Entry
| Check | Pass/Fail | Note |
|-------|-----------|------|

### 🔴 Bugs Found
- Screen | What's wrong | Root cause

### Verdict for L3
- PASS — proceed to L4
- FAIL — list blockers
