# PLATELY V2 — QA SESSIONS L1–L4
> Pre-release audit split into 4 focused sessions for free-tier Claude.
> Each session fits within token limits. Run in order.

---

## HOW TO USE

1. Start a **new chat** for each session
2. Paste at the top: **MEMORY.md + SKILLS.md + TASKS.md + this session file**
3. Claude reads source files via Desktop Commander + hits live backend
4. Gets a pass/fail report — **does NOT fix anything**
5. At the end of L4, get the final verdict + a fix prompt if needed

---

## SESSION MAP

| Session | File | Covers | Token Weight |
|---------|------|--------|-------------|
| L1 | QA_L1_Backend_Auth.md | Backend live tests + Auth + Onboarding | Light |
| L2 | QA_L2_Home_Recipes_Favorites.md | Home + Recipe Results + Recipe Detail + Favorites | Medium |
| L3 | QA_L3_History_Chat_Pantry_Scan.md | History + AI Chat + Pantry + Shopping + Scan | Medium |
| L4 | QA_L4_Profile_Global_Verdict.md | Profile + Global checks + Final verdict | Light |

---

## AFTER ALL 4 SESSIONS

- If **READY TO RELEASE ✅** → Marc rebuilds APK, Marco redeploys backend
- If **NEEDS FIXES 🔴** → paste the L-FIX prompt in a new chat, fix, then re-run relevant L sessions

---

## UPDATE TASKS.md AFTER EACH SESSION
At the end of L1/L2/L3/L4, add a row to the Session Log:
```
| L1 | QA audit — backend + auth | QA_L1_Backend_Auth.md |
```
And flip any resolved bugs to ✅ in the Bug Queue.
