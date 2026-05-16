"""
routes/recipes.py
- No ingredients  -> browse seeded DB (paginated), prefs applied for filtering/sorting
- With ingredients -> AI generates 5 tailored recipes using ingredients + user prefs
- AI results cached in-memory by (ingredients + prefs) fingerprint for 1 hour
- Tag values are normalised server-side so client filters always work
- AI recipe instructions are stored with \n between steps so detail screen splits correctly
"""

from flask import Blueprint, request, jsonify
from database import query, execute, PLACEHOLDER as ph, USE_PG
from app import limiter
import os, json, hashlib, requests, logging

bp     = Blueprint('recipes', __name__)
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL          = "google/gemma-4-31b-it:free"

_VALID_TAGS = {"Asian", "Italian", "Vegetarian", "Low-Cal", "High-Protein", "Filipino", "Budget", "Quick"}


def _normalise_tags(raw: str) -> str:
    aliases = {
        "high protein": "High-Protein", "high-protein": "High-Protein", "highprotein": "High-Protein",
        "low cal": "Low-Cal", "low-cal": "Low-Cal", "lowcal": "Low-Cal", "low calorie": "Low-Cal",
        "vegetarian": "Vegetarian", "vegan": "Vegetarian",
        "asian": "Asian", "italian": "Italian", "filipino": "Filipino", "pinoy": "Filipino",
        "budget": "Budget", "cheap": "Budget", "affordable": "Budget",
        "quick": "Quick", "fast": "Quick",
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
            cached = json.loads(rows[0]["recipes_json"])
            if isinstance(cached, list) and len(cached) > 0:
                return cached
    except Exception as e:
        logger.warning("Cache read error: %s", e)
    return None


def _cache_set(fp: str, data: list):
    if not data or len(data) == 0:
        logger.info("Skipping cache write -- empty result set")
        return
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
        "lose":     f"cutting -- target {cal_goal} kcal/day, high protein {pro_goal}g/day, low fat",
        "gain":     f"bulking -- target {cal_goal} kcal/day, high protein {pro_goal}g/day, calorie-dense",
        "maintain": f"maintaining -- target {cal_goal} kcal/day, protein {pro_goal}g/day, balanced macros",
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
3. Cost must be realistic: under 200 PHP per serving in the Philippines.
4. Adjust macros to the user's goal -- do not ignore it.
5. Respect ALL dietary restrictions -- do not include forbidden ingredients.
6. Tags MUST be chosen ONLY from this exact list: Filipino, Asian, Italian, Vegetarian, Low-Cal, High-Protein, Budget, Quick
   - Use "Filipino" for any traditional Filipino dish (adobo, sinigang, tinola, etc.)
   - Use "Budget" for dishes that cost under 80 PHP per serving
   - Use "Quick" for dishes ready in 15 minutes or less
   - Use 1-3 tags per recipe. Match them accurately.
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
    "tags": "Filipino,High-Protein",
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


def _extract_json_array(raw: str) -> str:
    """Robustly extract a JSON array from AI response, even if wrapped in markdown."""
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
    start = raw.find("[")
    end   = raw.rfind("]")
    if start != -1 and end != -1 and end > start:
        return raw[start:end + 1]
    return raw


def _generate_ai_recipes(ingredients: list, prefs: dict) -> list:
    key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not key:
        logger.warning("OPENROUTER_API_KEY not set -- returning empty for DB fallback")
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

    if resp.status_code == 429:
        logger.warning("OpenRouter 429 rate limit -- AI recipe gen failed")
        raise requests.exceptions.HTTPError(response=resp)
    if resp.status_code == 503:
        logger.warning("OpenRouter 503 unavailable -- AI recipe gen failed")
        raise requests.exceptions.HTTPError(response=resp)

    resp.raise_for_status()
    raw = resp.json()["choices"][0]["message"]["content"].strip()

    logger.info("Raw OpenRouter recipe response (first 400 chars): %s", raw[:400])

    raw = _extract_json_array(raw)
    recipes = json.loads(raw)

    if not isinstance(recipes, list):
        logger.warning("AI returned non-list JSON -- got: %s", type(recipes))
        return []

    cleaned = []
    for i, r in enumerate(recipes):
        if not isinstance(r, dict):
            continue
        r["tags"]         = _normalise_tags(str(r.get("tags", "")))
        r["id"]           = -(i + 1)
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


def _browse_query(prefs: dict, per_page: int, offset: int) -> list:
    """
    Browse mode query -- applies dietary pref filters to the DB result set.
    - pref_veg=True  -> only show Vegetarian-tagged recipes
    - pref_hipro=True -> sort High-Protein recipes to the top
    Gluten/dairy have no reliable DB column so we skip filtering for them here
    (they apply in AI mode via _build_prompt).
    """
    pref_veg   = prefs.get("pref_veg", False)
    pref_hipro = prefs.get("pref_hipro", True)

    base_sql = (
        "SELECT r.*, n.calories, n.protein, n.carbs, n.fat, n.cost_php "
        "FROM recipes r LEFT JOIN nutrition n ON n.recipe_id = r.id"
    )

    where_clauses = []
    params: list = []

    if pref_veg:
        # Filter to only vegetarian-tagged recipes
        if USE_PG:
            where_clauses.append(f"r.tags ILIKE {ph}")
            params.append("%Vegetarian%")
        else:
            where_clauses.append(f"LOWER(r.tags) LIKE {ph}")
            params.append("%vegetarian%")

    where_sql = ""
    if where_clauses:
        where_sql = " WHERE " + " AND ".join(where_clauses)

    # Sorting: High-Protein first if pref_hipro, then by id
    if pref_hipro:
        if USE_PG:
            order_sql = " ORDER BY CASE WHEN r.tags ILIKE '%High-Protein%' THEN 0 ELSE 1 END, n.protein DESC NULLS LAST, r.id"
        else:
            order_sql = " ORDER BY CASE WHEN LOWER(r.tags) LIKE '%high-protein%' THEN 0 ELSE 1 END, COALESCE(n.protein, 0) DESC, r.id"
    else:
        order_sql = " ORDER BY r.id"

    limit_sql = f" LIMIT {ph} OFFSET {ph}"
    params += [per_page, offset]

    return query(base_sql + where_sql + order_sql + limit_sql, tuple(params))


@bp.route("/api/recipes", methods=["POST"])
@limiter.limit("30 per minute")
def get_recipes():
    try:
        data = request.json or {}

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
        cal_goal     = prefs.get("cal_goal", 2200)
        protein_goal = prefs.get("protein_goal", 120)
        if not isinstance(cal_goal, (int, float)) or cal_goal < 500 or cal_goal > 10000:
            prefs["cal_goal"] = 2200
        if not isinstance(protein_goal, (int, float)) or protein_goal < 20 or protein_goal > 500:
            prefs["protein_goal"] = 120
        for k in ("pref_veg", "pref_gluten", "pref_dairy", "pref_hipro"):
            if k in prefs and not isinstance(prefs[k], bool):
                prefs[k] = bool(prefs.get(k, False))
        page     = max(1, int(data.get("page", 1)))
        per_page = min(50, max(1, int(data.get("per_page", 50))))
        offset   = (page - 1) * per_page

        # -- Browse mode (no ingredients) -- applies pref filtering/sorting --
        if not ingredients:
            try:
                rows = _browse_query(prefs, per_page, offset)
            except Exception as e:
                logger.warning("Browse query failed (%s), retrying once...", e)
                rows = _browse_query(prefs, per_page, offset)
            try:
                total = query("SELECT COUNT(*) as c FROM recipes")[0]["c"]
            except Exception:
                total = len(rows)
            result = []
            for r in rows:
                nutrition = {
                    "calories": r.get("calories") or 0, "protein": r.get("protein") or 0,
                    "carbs":    r.get("carbs")    or 0, "fat":     r.get("fat")      or 0,
                    "cost_php": r.get("cost_php") or 0,
                }
                d = _recipe_row_to_dict(r, nutrition=nutrition)
                d["image_url"] = r.get("image_url", "")
                result.append(d)
            return jsonify({
                "status": "ok", "data": result,
                "meta": {"page": page, "per_page": per_page, "total": total},
            }), 200

        # -- Ingredient mode -- AI-generated tailored recipes --
        fp_data = {
            "ings":  sorted(ingredients),
            "goal":  prefs.get("goal", "maintain"),
            "veg":   prefs.get("pref_veg", False),
            "glut":  prefs.get("pref_gluten", False),
            "dairy": prefs.get("pref_dairy", False),
            "hipro": prefs.get("pref_hipro", True),
        }
        fingerprint = hashlib.md5(json.dumps(fp_data, sort_keys=True).encode()).hexdigest()

        cached = _cache_get(fingerprint)
        if cached:
            logger.info("AI recipe cache hit (%s)", fingerprint[:8])
            return jsonify({"status": "ok", "data": cached, "meta": {"source": "cache"}}), 200

        ai_error_msg = None
        try:
            ai_recipes = _generate_ai_recipes(ingredients, prefs)
        except requests.exceptions.Timeout:
            logger.warning("AI recipe generation timed out -- DB fallback")
            ai_recipes = []
            ai_error_msg = "AI timed out"
        except requests.exceptions.HTTPError as e:
            status_code = e.response.status_code if e.response is not None else 0
            if status_code == 429:
                ai_error_msg = "AI busy -- showing saved recipes instead"
            else:
                ai_error_msg = f"AI service error ({status_code})"
            logger.warning("AI recipe HTTP error (%s) -- DB fallback", e)
            ai_recipes = []
        except (json.JSONDecodeError, KeyError, IndexError, ValueError) as e:
            logger.warning("AI recipe parse error (%s) -- DB fallback", e)
            ai_recipes = []
            ai_error_msg = "AI response parse error"

        if ai_recipes:
            # Sort AI recipes by how many scanned ingredients they use (most matches first)
            ing_set = set(ingredients)
            for r in ai_recipes:
                recipe_ings = set(i["name"].lower().strip() for i in r.get("ingredients", []))
                r["_match_count"] = len(ing_set & recipe_ings)
            ai_recipes.sort(key=lambda r: r["_match_count"], reverse=True)
            for r in ai_recipes:
                r.pop("_match_count", None)
            _cache_set(fingerprint, ai_recipes)
            return jsonify({"status": "ok", "data": ai_recipes, "meta": {"source": "ai"}}), 200

        # -- DB fallback when AI fails --
        # Rank by how many scanned ingredients each recipe matches (most matches first)
        placeholders = ",".join([ph] * len(ingredients))
        rows = query(
            f"SELECT r.*, n.calories, n.protein, n.carbs, n.fat, n.cost_php, "
            f"COUNT(DISTINCT i.id) as match_count "
            f"FROM recipes r LEFT JOIN nutrition n ON n.recipe_id = r.id "
            f"JOIN recipe_ingredients ri ON ri.recipe_id = r.id "
            f"JOIN ingredients i ON i.id = ri.ingredient_id "
            f"WHERE LOWER(i.name) IN ({placeholders}) "
            f"GROUP BY r.id, n.calories, n.protein, n.carbs, n.fat, n.cost_php "
            f"ORDER BY match_count DESC, n.protein DESC NULLS LAST, r.id",
            tuple(ingredients),
        )
        result = []
        for r in rows:
            nutrition = {
                "calories": r.get("calories") or 0, "protein": r.get("protein") or 0,
                "carbs":    r.get("carbs")    or 0, "fat":     r.get("fat")      or 0,
                "cost_php": r.get("cost_php") or 0,
            }
            d = _recipe_row_to_dict(r, nutrition=nutrition)
            d["image_url"] = r.get("image_url", "")
            result.append(d)

        logger.info("DB fallback returned %d recipes (ai_error: %s)", len(result), ai_error_msg)

        if result:
            meta = {"source": "db"}
            if ai_error_msg:
                meta["ai_note"] = ai_error_msg
            return jsonify({"status": "ok", "data": result, "meta": meta}), 200
        else:
            msg = ai_error_msg or "No recipes found for those ingredients"
            return jsonify({"status": "error", "message": msg, "data": []}), 200

    except (ValueError, TypeError) as e:
        return jsonify({"status": "error", "message": f"Invalid params: {e}"}), 400
    except Exception:
        logger.exception("get_recipes error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route("/api/recipe/<int:recipe_id>", methods=["GET"])
@limiter.limit("60 per minute")
def get_recipe(recipe_id):
    try:
        if recipe_id < 0:
            return jsonify({
                "status": "error",
                "message": "AI-generated recipe -- use full data from results list.",
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
