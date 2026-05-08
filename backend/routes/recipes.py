"""
routes/recipes.py
- No ingredients  → browse seeded DB (paginated)
- With ingredients → AI generates 5 tailored recipes using ingredients + user prefs
- AI results cached in-memory by (ingredients + prefs) fingerprint for 1 hour
- Tag values are normalised server-side so client filters always work
- AI recipe instructions are stored with \n between steps so detail screen splits correctly
"""

from flask import Blueprint, request, jsonify
from database import query, execute, PLACEHOLDER as ph, USE_PG
import os, json, hashlib, requests, logging

bp     = Blueprint('recipes', __name__)
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL          = "google/gemma-3-27b-it:free"

_VALID_TAGS = {"Asian", "Italian", "Vegetarian", "Low-Cal", "High-Protein", "Filipino"}


def _normalise_tags(raw: str) -> str:
    """Force tag values to match the exact strings the Flutter filter expects."""
    aliases = {
        "high protein": "High-Protein",
        "high-protein": "High-Protein",
        "highprotein": "High-Protein",
        "low cal": "Low-Cal",
        "low-cal": "Low-Cal",
        "lowcal": "Low-Cal",
        "low calorie": "Low-Cal",
        "vegetarian": "Vegetarian",
        "vegan": "Vegetarian",
        "asian": "Asian",
        "italian": "Italian",
        "filipino": "Filipino",
        "pinoy": "Filipino",
    }
    parts = [t.strip() for t in raw.split(",")]
    normalised = []
    for p in parts:
        key = p.lower()
        mapped = aliases.get(key, p)
        if mapped in _VALID_TAGS and mapped not in normalised:
            normalised.append(mapped)
    return ",".join(normalised)


def _recipe_row_to_dict(r, nutrition=None, ingredients=None) -> dict:
    d = {
        "id":           r["id"],
        "name":         r["name"],
        "cook_time":    r["cook_time"],
        "difficulty":   r["difficulty"],
        "instructions": r["instructions"],
        "tags":         r.get("tags", ""),
    }
    if nutrition:
        d["nutrition"] = nutrition
    if ingredients is not None:
        d["ingredients"] = ingredients
    return d


def _cache_get(fp: str):
    try:
        if USE_PG:
            rows = query(
                f"SELECT recipes_json FROM ai_recipe_cache WHERE cache_key = {ph} AND created_at > NOW() - INTERVAL '1 hour'",
                (fp,)
            )
        else:
            rows = query(
                f"SELECT recipes_json FROM ai_recipe_cache WHERE cache_key = {ph} AND datetime(created_at) > datetime('now', '-1 hour')",
                (fp,)
            )
        if rows:
            return json.loads(rows[0]["recipes_json"])
    except Exception as e:
        logger.warning("Cache read error: %s", e)
    return None


def _cache_set(fp: str, data: list):
    try:
        recipes_json = json.dumps(data)
        if USE_PG:
            execute(
                f"INSERT INTO ai_recipe_cache (cache_key, recipes_json) VALUES ({ph},{ph}) ON CONFLICT (cache_key) DO UPDATE SET recipes_json = EXCLUDED.recipes_json, created_at = CURRENT_TIMESTAMP",
                (fp, recipes_json)
            )
        else:
            execute(
                f"INSERT OR REPLACE INTO ai_recipe_cache (cache_key, recipes_json, created_at) VALUES ({ph},{ph}, datetime('now'))",
                (fp, recipes_json)
            )
    except Exception as e:
        logger.warning("Cache write error: %s", e)


def _build_prompt(ingredients: list, prefs: dict) -> str:
    goal       = prefs.get("goal", "maintain")
    cal_goal   = prefs.get("cal_goal", 2200)
    pro_goal   = prefs.get("protein_goal", 120)
    vegetarian = prefs.get("pref_veg", False)
    no_gluten  = prefs.get("pref_gluten", False)
    no_dairy   = prefs.get("pref_dairy", False)
    hi_protein = prefs.get("pref_hipro", True)

    restrictions = []
    if vegetarian: restrictions.append("vegetarian (absolutely no meat, poultry, or seafood)")
    if no_gluten:  restrictions.append("strictly gluten-free (no wheat, barley, rye, regular soy sauce)")
    if no_dairy:   restrictions.append("strictly dairy-free (no milk, cheese, butter, cream)")

    goal_map = {
        "lose":     f"cutting — target {cal_goal} kcal/day, high protein {pro_goal}g/day, low fat",
        "gain":     f"bulking — target {cal_goal} kcal/day, high protein {pro_goal}g/day, calorie-dense",
        "maintain": f"maintaining — target {cal_goal} kcal/day, protein {pro_goal}g/day, balanced macros",
    }
    goal_desc  = goal_map.get(goal, goal_map["maintain"])
    restr_line = f"Dietary restrictions (MUST follow): {', '.join(restrictions)}." if restrictions else "No dietary restrictions."
    hipro_line = "Prioritise recipes with 30g+ protein per serving." if hi_protein else ""

    return f"""You are Plately, a cooking AI for budget students in the Philippines.

Generate exactly 5 recipe suggestions using these available ingredients: {', '.join(ingredients)}.

User fitness goal: {goal_desc}
{restr_line}
{hipro_line}

STRICT RULES:
1. Use ONLY the provided ingredients plus max 3 common pantry items (salt, oil, water, soy sauce, pepper, vinegar, sugar).
2. Every recipe must be cookable in a student dorm with basic equipment.
3. Cost must be realistic: under ₱200 per serving in the Philippines.
4. Adjust macros to the user's goal — do not ignore it.
5. Respect ALL dietary restrictions — do not include forbidden ingredients.
6. Tags MUST be chosen ONLY from this exact list: Asian, Italian, Vegetarian, Low-Cal, High-Protein
   Use 1-2 tags per recipe. Match them accurately.
7. Instructions MUST be exactly 5 numbered steps separated by newline characters.
   Format: "1. Step one.\\n2. Step two.\\n3. Step three.\\n4. Step four.\\n5. Step five."
8. Difficulty must be exactly "Easy", "Medium", or "Hard".
9. cook_time format: "X min" (e.g. "20 min").

Respond ONLY with a valid JSON array. No markdown fences, no explanation, no extra text before or after.
[
  {{
    "name": "Recipe Name",
    "cook_time": "20 min",
    "difficulty": "Easy",
    "tags": "Asian,High-Protein",
    "instructions": "1. Step one.\\n2. Step two.\\n3. Step three.\\n4. Step four.\\n5. Step five.",
    "ingredients": [
      {{"name": "chicken", "amount": "200g"}},
      {{"name": "garlic", "amount": "3 cloves"}}
    ],
    "nutrition": {{
      "calories": 420,
      "protein": 38,
      "carbs": 30,
      "fat": 12
    }}
  }}
]"""


def _generate_ai_recipes(ingredients: list, prefs: dict) -> list:
    key = os.getenv("OPENROUTER_API_KEY", "")
    if not key:
        logger.warning("OPENROUTER_API_KEY not set — returning empty for DB fallback")
        return []

    prompt = _build_prompt(ingredients, prefs)
    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type":  "application/json",
            "HTTP-Referer":  "https://plately.app",
            "X-Title":       "Plately",
        },
        json={
            "model":      MODEL,
            "messages":   [{"role": "user", "content": prompt}],
            "max_tokens": 2000,
        },
        timeout=35,
    )
    resp.raise_for_status()
    raw = resp.json()["choices"][0]["message"]["content"].strip()

    # Strip markdown fences if model adds them
    if "```" in raw:
        parts = raw.split("```")
        for p in parts:
            stripped = p.strip()
            if stripped.startswith("json"):
                stripped = stripped[4:].strip()
            if stripped.startswith("["):
                raw = stripped
                break

    raw = raw.strip()
    # Ensure it starts with [ and ends with ]
    start = raw.find("[")
    end   = raw.rfind("]")
    if start != -1 and end != -1:
        raw = raw[start:end + 1]

    recipes = json.loads(raw)
    if not isinstance(recipes, list):
        return []

    cleaned = []
    for i, r in enumerate(recipes):
        if not isinstance(r, dict):
            continue
        # Normalise tags so Flutter filters always match
        r["tags"]         = _normalise_tags(str(r.get("tags", "")))
        r["id"]           = -(i + 1)   # negative = AI-generated, won't conflict with DB
        r["difficulty"]   = str(r.get("difficulty", "Easy")).strip()
        r["cook_time"]    = str(r.get("cook_time", "20 min")).strip()
        r["instructions"] = str(r.get("instructions", "")).strip()
        if "nutrition" not in r or not isinstance(r["nutrition"], dict):
            r["nutrition"] = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
        if "ingredients" not in r or not isinstance(r["ingredients"], list):
            r["ingredients"] = []
        cleaned.append(r)

    logger.info("AI generated %d recipes for: %s", len(cleaned), ingredients)
    return cleaned


@bp.route("/api/recipes", methods=["POST"])
def get_recipes():
    """
    POST body:
    {
      "ingredients": ["chicken", "eggs"],
      "prefs": {
        "goal": "lose",           # lose | maintain | gain
        "cal_goal": 1800,
        "protein_goal": 140,
        "pref_veg": false,
        "pref_gluten": false,
        "pref_dairy": false,
        "pref_hipro": true
      },
      "page": 1, "per_page": 20   # browse mode only
    }
    """
    # Import limiter lazily to avoid circular import at module load time
    from app import limiter
    try:
        data = request.json or {}

        # ── Input validation ──────────────────────────────────────────────
        raw_ings = data.get("ingredients", [])
        if not isinstance(raw_ings, list):
            return jsonify({"status": "error", "message": "ingredients must be an array"}), 400
        if len(raw_ings) > 20:
            return jsonify({"status": "error", "message": "Maximum 20 ingredients allowed"}), 400
        for item in raw_ings:
            if not isinstance(item, str):
                return jsonify({"status": "error", "message": "Each ingredient must be a string"}), 400

        ingredients = [i.strip().lower() for i in raw_ings if i.strip()]
        prefs       = data.get("prefs") or {}
        if not isinstance(prefs, dict):
            prefs = {}
        page        = max(1, int(data.get("page", 1)))
        per_page    = min(50, max(1, int(data.get("per_page", 50))))
        offset      = (page - 1) * per_page

        # ── Browse mode (no ingredients) ──────────────────────────────────
        if not ingredients:
            rows = query(
                f"SELECT r.*, n.calories, n.protein, n.carbs, n.fat, n.cost_php "
                f"FROM recipes r LEFT JOIN nutrition n ON n.recipe_id = r.id "
                f"ORDER BY r.id LIMIT {ph} OFFSET {ph}",
                (per_page, offset),
            )
            total = query("SELECT COUNT(*) as c FROM recipes")[0]["c"]
            result = []
            for r in rows:
                nutrition = {
                    "calories": r.get("calories") or 0,
                    "protein":  r.get("protein")  or 0,
                    "carbs":    r.get("carbs")    or 0,
                    "fat":      r.get("fat")      or 0,
                    "cost_php": r.get("cost_php") or 0,
                }
                d = _recipe_row_to_dict(r, nutrition=nutrition)
                d["image_url"] = r.get("image_url", "")
                result.append(d)
            return jsonify({
                "status": "ok",
                "data":   result,
                "meta":   {"page": page, "per_page": per_page, "total": total},
            }), 200

        # ── Ingredient mode — AI-generated tailored recipes ───────────────
        fp_data = {
            "ings":  sorted(ingredients),
            "goal":  prefs.get("goal", "maintain"),
            "veg":   prefs.get("pref_veg", False),
            "glut":  prefs.get("pref_gluten", False),
            "dairy": prefs.get("pref_dairy", False),
            "hipro": prefs.get("pref_hipro", True),
        }
        fingerprint = hashlib.md5(
            json.dumps(fp_data, sort_keys=True).encode()
        ).hexdigest()

        cached = _cache_get(fingerprint)
        if cached:
            logger.info("AI recipe cache hit (%s)", fingerprint[:8])
            return jsonify({"status": "ok", "data": cached, "meta": {"source": "cache"}}), 200

        try:
            ai_recipes = _generate_ai_recipes(ingredients, prefs)
        except requests.exceptions.Timeout:
            logger.warning("AI recipe generation timed out — DB fallback")
            ai_recipes = []
        except requests.exceptions.HTTPError as e:
            logger.warning("AI recipe HTTP error (%s) — DB fallback", e)
            ai_recipes = []
        except (json.JSONDecodeError, KeyError, IndexError, ValueError) as e:
            logger.warning("AI recipe parse error (%s) — DB fallback", e)
            ai_recipes = []

        if ai_recipes:
            _cache_set(fingerprint, ai_recipes)
            return jsonify({"status": "ok", "data": ai_recipes, "meta": {"source": "ai"}}), 200

        # ── DB fallback when AI fails ─────────────────────────────────────
        placeholders = ",".join([ph] * len(ingredients))
        rows = query(
            f"SELECT DISTINCT r.*, n.calories, n.protein, n.carbs, n.fat, n.cost_php "
            f"FROM recipes r LEFT JOIN nutrition n ON n.recipe_id = r.id "
            f"JOIN recipe_ingredients ri ON ri.recipe_id = r.id "
            f"JOIN ingredients i ON i.id = ri.ingredient_id "
            f"WHERE LOWER(i.name) IN ({placeholders}) ORDER BY r.id",
            tuple(ingredients),
        )
        result = []
        for r in rows:
            nutrition = {
                "calories": r.get("calories") or 0,
                "protein":  r.get("protein")  or 0,
                "carbs":    r.get("carbs")    or 0,
                "fat":      r.get("fat")      or 0,
                "cost_php": r.get("cost_php") or 0,
            }
            d = _recipe_row_to_dict(r, nutrition=nutrition)
            d["image_url"] = r.get("image_url", "")
            result.append(d)
        logger.info("DB fallback returned %d recipes", len(result))
        return jsonify({"status": "ok", "data": result, "meta": {"source": "db"}}), 200

    except (ValueError, TypeError) as e:
        return jsonify({"status": "error", "message": f"Invalid params: {e}"}), 400
    except Exception:
        logger.exception("get_recipes error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route("/api/recipe/<int:recipe_id>", methods=["GET"])
def get_recipe(recipe_id):
    """GET /api/recipe/<id> — full detail. Negative IDs are AI-generated (not in DB)."""
    try:
        if recipe_id < 0:
            return jsonify({
                "status":  "error",
                "message": "AI-generated recipe — use full data from results list.",
            }), 404

        rows = query(
            f"SELECT r.*, n.calories, n.protein, n.carbs, n.fat "
            f"FROM recipes r LEFT JOIN nutrition n ON n.recipe_id = r.id "
            f"WHERE r.id = {ph}",
            (recipe_id,),
        )
        if not rows:
            return jsonify({"status": "error", "message": "Recipe not found"}), 404

        r        = rows[0]
        ing_rows = query(
            f"SELECT i.name, ri.amount FROM recipe_ingredients ri "
            f"JOIN ingredients i ON i.id = ri.ingredient_id WHERE ri.recipe_id = {ph}",
            (recipe_id,),
        )
        nutrition   = {
            "calories": r.get("calories") or 0, "protein": r.get("protein") or 0,
            "carbs":    r.get("carbs")    or 0, "fat":     r.get("fat")     or 0,
        }
        ingredients = [{"name": i["name"], "amount": i["amount"]} for i in ing_rows]
        return jsonify({
            "status": "ok",
            "data":   _recipe_row_to_dict(r, nutrition=nutrition, ingredients=ingredients),
        }), 200

    except Exception:
        logger.exception("get_recipe error id=%d", recipe_id)
        return jsonify({"status": "error", "message": "Internal error."}), 500
