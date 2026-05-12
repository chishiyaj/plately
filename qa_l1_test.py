import urllib.request, json, urllib.error

BASE = "https://plately-production.up.railway.app"

def get(path):
    try:
        r = urllib.request.urlopen(BASE + path, timeout=20)
        return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())
    except Exception as ex:
        return 0, str(ex)

def post(path, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        BASE + path, data=data,
        headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        r = urllib.request.urlopen(req, timeout=25)
        return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())
    except Exception as ex:
        return 0, str(ex)

def delete(path):
    req = urllib.request.Request(BASE + path, method="DELETE")
    try:
        r = urllib.request.urlopen(req, timeout=15)
        return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())
    except Exception as ex:
        return 0, str(ex)

results = []

def check(name, status, body, expect_status=200, expect_key=None, expect_val=None):
    ok = status == expect_status
    note = ""
    if expect_key and ok:
        val = body
        for k in expect_key.split("."):
            if isinstance(val, dict):
                val = val.get(k)
            else:
                val = None
                break
        if expect_val is not None:
            ok = ok and (val == expect_val)
            note = f"  [{expect_key}={val} expected={expect_val}]"
        else:
            ok = ok and (val is not None)
            note = f"  [{expect_key}={val}]"
    icon = "PASS" if ok else "FAIL"
    results.append((name, ok))
    print(f"[{icon}] {name}{note}  HTTP={status}")
    if not ok:
        print(f"       body={str(body)[:200]}")

print("=" * 60)
print("PLATELY QA L1 — Backend + Auth Code Audit")
print("=" * 60)
print()

# ── BACKEND LIVE TESTS ─────────────────────────────────────────────────────
print("--- SECTION 1: Backend Live Tests ---")
print()

# T1 health
s, d = get("/api/health")
check("T1 GET /api/health returns 200 + status=ok", s, d, 200, "status", "ok")

# T2 goals
s, d = post("/api/goals", {
    "weight": 70, "height": 175, "age": 21,
    "sex": "male", "goal": "maintain", "activity": "moderate"
})
check("T2 POST /api/goals returns 200", s, d, 200, "status", "ok")
check("T2b goals returns calorie_target", s, d, 200, "data.calorie_target")
check("T2c goals returns protein_target", s, d, 200, "data.protein_target")
cal = d.get("data", {}).get("calorie_target", 0) if isinstance(d.get("data"), dict) else 0
check("T2d calorie_target in realistic range (1800-3500)", s, {"ok": 1800 <= cal <= 3500}, 200, "ok", True)

# T3 recipes browse
s, d = post("/api/recipes", {"ingredients": [], "prefs": {}, "page": 1, "per_page": 5})
check("T3 POST /api/recipes browse returns 200", s, d, 200, "status", "ok")
count = len(d.get("data", [])) if isinstance(d.get("data"), list) else 0
check("T3b browse returns >0 recipes", s, {"ok": count > 0}, 200, "ok", True)
if count > 0:
    r0 = d["data"][0]
    check("T3c recipe has id field", s, {"ok": "id" in r0}, 200, "ok", True)
    check("T3d recipe has name field", s, {"ok": "name" in r0}, 200, "ok", True)
    check("T3e recipe has nutrition field", s, {"ok": "nutrition" in r0}, 200, "ok", True)

# T4 recipes with ingredients (AI or DB fallback)
s, d = post("/api/recipes", {
    "ingredients": ["chicken", "eggs", "garlic"],
    "prefs": {"goal": "maintain", "cal_goal": 2200, "protein_goal": 120}
})
check("T4 POST /api/recipes with ingredients returns 200", s, d, 200, "status", "ok")
count4 = len(d.get("data", [])) if isinstance(d.get("data"), list) else 0
check("T4b ingredient search returns recipes", s, {"ok": count4 > 0}, 200, "ok", True)
src = d.get("meta", {}).get("source", "") if isinstance(d.get("meta"), dict) else ""
check("T4c source is ai or db or cache", s, {"ok": src in ("ai", "db", "cache")}, 200, "ok", True)

# T4d recipe detail for a real ID
if count4 > 0 and isinstance(d.get("data"), list):
    first_id = d["data"][0].get("id", -999)
    if first_id > 0:
        s2, d2 = get(f"/api/recipe/{first_id}")
        check("T4d GET /api/recipe/<id> returns 200", s2, d2, 200, "status", "ok")
        check("T4e recipe detail has ingredients", s2, d2, 200, "data.ingredients")

# T5 history GET
s, d = get("/api/history?user_id=qa_test_l1")
check("T5 GET /api/history returns 200", s, d, 200, "status", "ok")
check("T5b history data is array", s, {"ok": isinstance(d.get("data"), list)}, 200, "ok", True)

# T6 history stats
s, d = get("/api/history/stats?user_id=qa_test_l1")
check("T6 GET /api/history/stats returns 200", s, d, 200, "status", "ok")
check("T6b stats has total_sessions", s, d, 200, "data.total_sessions")

# T7 history POST
s, d = post("/api/history", {
    "user_id": "qa_test_l1", "action_type": "cooked",
    "ingredient_names": "chicken,eggs", "recipe_count": 1,
    "calories_logged": 420, "protein_logged": 38
})
check("T7 POST /api/history returns 200", s, d, 200, "status", "ok")
check("T7b logged=True", s, d, 200, "data.logged", True)

# T8 history daily
s, d = get("/api/history/daily?user_id=qa_test_l1&date=2026-05-12")
check("T8 GET /api/history/daily returns 200", s, d, 200, "status", "ok")
check("T8b daily has total_calories field", s, d, 200, "data.total_calories")

# T9 DELETE history (user_id guard)
s, d = delete("/api/history?user_id=default")
check("T9 DELETE /api/history with user_id=default returns 400", s, d, 400)
s, d = delete("/api/history?user_id=qa_test_l1")
check("T9b DELETE /api/history with valid user_id returns 200", s, d, 200, "status", "ok")

# T10 chat
s, d = post("/api/chat", {"message": "What can I cook with chicken and eggs?", "user_id": "qa_test_l1"})
check("T10 POST /api/chat returns 200", s, d, 200, "status", "ok")
reply = d.get("data", {}).get("reply", "") if isinstance(d.get("data"), dict) else ""
check("T10b chat reply is non-empty string", s, {"ok": isinstance(reply, str) and len(reply) > 10}, 200, "ok", True)

# T11 scan - invalid base64
s, d = post("/api/scan", {"image_base64": "not_valid_base64!!!"})
check("T11 POST /api/scan with invalid base64 returns 400", s, d, 400)

# T12 scan - valid tiny base64 (1x1 pixel JPEG)
tiny_b64 = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAABgUEA/8QAIhAAAQQCAgMBAAAAAAAAAAAAAQIDBAUREiExQVH/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8Amk2VdO1fQ6utYtJKWxuVdDWfJoqEjRb5ZOEJxnj6UUUAf//Z"
s, d = post("/api/scan", {"image_base64": tiny_b64})
check("T12 POST /api/scan with valid image returns 200", s, d, 200, "status", "ok")
check("T12b scan returns ingredients array", s, {"ok": isinstance(d.get("data", {}).get("ingredients"), list)}, 200, "ok", True)

# T13 recipe prefs validation - bad cal_goal
s, d = post("/api/recipes", {
    "ingredients": [],
    "prefs": {"cal_goal": "bad_value", "protein_goal": -5}
})
check("T13 /api/recipes bad prefs still returns 200 (clamped)", s, d, 200, "status", "ok")

# T14 goals missing field
s, d = post("/api/goals", {"weight": 70})
check("T14 /api/goals missing fields returns 400", s, d, 400, "status", "error")

print()
print("=" * 60)
print(f"RESULTS: {sum(1 for _,ok in results if ok)}/{len(results)} passed")
fails = [n for n, ok in results if not ok]
if fails:
    print("FAILED:", fails)
else:
    print("ALL BACKEND TESTS PASSED")
print("=" * 60)
