"""
routes/recipes.py — Recipe endpoints.
- No ingredients → browse seeded DB (paginated)
- With ingredients → AI generates tailored recipes based on ingredients + user prefs
- AI results cached by (ingredients + prefs) fingerprint to save tokens
"""

from flask import Blueprint, request, jsonify
from database import query, execute
from app import limiter
import os, json, hashlib, time, requests, logging

bp     = Blueprint('recipes', __name__)
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL          = "google/gemma-3-27b-it:free"
CACHE_TTL      = 3600   # 1 hour

# In-memory cache: {fingerprint: (recipes_list, timestamp)}
_ai_cache: dict[str, tuple[list, float]] = {}


# ── helpers ──────────────────────────────────────────────────────────────────

def _recipe_row_to_dict(r, nutrition=None, ingredients=None) -> dict:
    d = {
        "id":           r['id'],
        "name":         r['name'],
        "cook_time":    r['cook_time'],
        "difficulty":   r['difficulty'],
        "instructions": r['instructions'],
        "tags":         r.get('tags', ''),
    }
    if nutrition:
        d['nutrition'] = nutrition
    if ingredients is not None:
        d['ingredients'] = ingredients
    return d


def _cache_get(fp: str):
    if fp in _ai_cache:
        data, ts = _ai_cache[fp]
        if time.monotonic() - ts < CACHE_TTL:
            return data
        del _ai_cache[fp]
    return None


def _cache_set(fp: str, data: list):
    if len(_ai_cache) >= 100:
        oldest = min(_ai_cache, key=lambda k: _ai_cache[k][1])
        del _ai_cache[oldest]
    _ai_cache[fp] = (data, time.monotonic())


def _build_prompt(ingredients: list, prefs: dict) -> str:
    goal       = prefs.get('goal', 'maintain')       # lose / maintain / gain
    cal_goal   = prefs.get('cal_goal', 2200)
    pro_goal   = prefs.get('protein_goal', 120)
    vegetarian = prefs.get('pref_veg', False)
    no_gluten  = prefs.get('pref_gluten', False)
    no_dairy   = prefs.get('pref_dairy', False)
    hi_protein = prefs.get('pref_hipro', True)

    restrictions = []
    if vegetarian: restrictions.append("vegetarian (no meat or seafood)")
    if no_gluten:  restrictions.append("gluten-free")
    if no_dairy:   restrictions.append("dairy-free")

    goal_desc = {
        'lose':     f'cutting calories (target ~{cal_goal} kcal/day, high protein {pro_goal}g/day)',
        'gain':     f'bulking (target ~{cal_goal} kcal/day, high protein {pro_goal}g/day)',
        'maintain': f'maintaining weight (target ~{cal_goal} kcal/day, protein ~{pro_goal}g/day)',
    }.get(goal, 'maintaining weight')

    restr_line = f"Dietary restrictions: {', '.join(restrictions)}." if restrictions else "No dietary restrictions."
    hipro_line = "Prioritize high-protein recipes (30g+ per serving)." if hi_protein else ""

    return f"""You are Plately, a cooking AI for budget students in the Philippines.

Generate exactly 5 recipe suggestions based on these available ingredients: {', '.join(ingredients)}.

User goal: {goal_desc}
{restr_line}
{hipro_line}

RULES:
- Use mainly the provided ingredients. You may add 1-2 common pantry items (salt, oil, water, soy sauce).
- Each recipe must be realistic, affordable (under ₱200/serving), and cookable by a student.
- Adjust macros to fit the user's goal: {'lower calories, higher protein' if goal == 'lose' else 'higher calories and protein' if goal == 'gain' else 'balanced macros'}.
- Respect dietary restrictions strictly.
- Tags must only be from: Asian, Italian, Vegetarian, Low-Cal, High-Protein. Pick 1-2 per recipe.

Respond ONLY with a valid JSON array. No markdown, no explanation, no extra text.
Format:
[
  {{
    "name": "Recipe Name",
    "cook_time": "20 mins",
    "difficulty": "Easy",
    "tags": "Asian,High-Protein",
    "instructions": "1. Step one. 2. Step two. 3. Step three. 4. Step four. 5. Step five.",
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
        logger.warning("OPENROUTER_API_KEY not set — returning DB fallback")
        return []

    prompt = _build_prompt(ingredients, prefs)

    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://plately.app",
            "X-Title": "Plately",
        },
        json={
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 1800,
        },
        timeout=30,
    )
    resp.raise_for_status()
    raw = resp.json()["choices"][0]["message"]["content"].strip()

    # Strip markdown fences if model adds them
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    recipes = json.loads(raw)

    # Assign synthetic IDs (negative = AI-generated, won't conflict with DB)
    for i, r in enumerate(recipes):
        r['id'] = -(i + 1)
        if 'nutrition' not in r:
            r['nutrition'] = {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0}
        if 'ingredients' not in r:
            r['ingredients'] = []

    logger.info("AI generated %d recipes for ingredients: %s", len(recipes), ingredients)
    return recipes



# ── routes ───────────────────────────────────────────────────────────────────

@bp.route('/api/recipes', methods=['POST'])
@limiter.limit("30 per minute")
def get_recipes():
    """
    POST body:
    {
      "ingredients": ["chicken", "eggs"],   ← triggers AI generation
      "prefs": {                             ← user profile prefs (optional)
        "goal": "lose",
        "cal_goal": 1800,
        "protein_goal": 140,
        "pref_veg": false,
        "pref_gluten": false,
        "pref_dairy": false,
        "pref_hipro": true
      },
      "page": 1, "per_page": 20            ← only used in browse (no ingredients)
    }
    """
    try:
        data        = request.json or {}
        ingredients = [i.strip().lower() for i in data.get('ingredients', []) if i.strip()]
        prefs       = data.get('prefs') or {}
        page        = max(1, int(data.get('page', 1)))
        per_page    = min(50, max(1, int(data.get('per_page', 50))))
        offset      = (page - 1) * per_page

        # ── Browse mode (no ingredients) — return seeded DB recipes ──────────
        if not ingredients:
            rows = query("""
                SELECT r.*, n.calories, n.protein, n.carbs, n.fat
                FROM recipes r
                LEFT JOIN nutrition n ON n.recipe_id = r.id
                ORDER BY r.id
                LIMIT ? OFFSET ?
            """, (per_page, offset))
            total = query("SELECT COUNT(*) as c FROM recipes")[0]['c']

            result = []
            for r in rows:
                nutrition = {
                    "calories": r.get('calories') or 0,
                    "protein":  r.get('protein')  or 0,
                    "carbs":    r.get('carbs')    or 0,
                    "fat":      r.get('fat')      or 0,
                }
                ing_rows = query("""
                    SELECT i.name, ri.amount
                    FROM recipe_ingredients ri
                    JOIN ingredients i ON i.id = ri.ingredient_id
                    WHERE ri.recipe_id = ?
                """, (r['id'],))
                ingredients = [{"name": i['name'], "amount": i['amount']} for i in ing_rows]
                result.append(_recipe_row_to_dict(r, nutrition=nutrition, ingredients=ingredients))

            return jsonify({
                "status": "ok",
                "data": result,
                "meta": {"page": page, "per_page": per_page, "total": total},
            }), 200

        # ── Ingredient mode — AI-generated tailored recipes ───────────────────
        # Build cache fingerprint from sorted ingredients + relevant prefs
        fp_data = {
            "ings":  sorted(ingredients),
            "goal":  prefs.get('goal', 'maintain'),
            "veg":   prefs.get('pref_veg', False),
            "glut":  prefs.get('pref_gluten', False),
            "dairy": prefs.get('pref_dairy', False),
            "hipro": prefs.get('pref_hipro', True),
        }
        fingerprint = hashlib.md5(json.dumps(fp_data, sort_keys=True).encode()).hexdigest()

        cached = _cache_get(fingerprint)
        if cached:
            logger.info("AI recipe cache hit for fingerprint %s", fingerprint[:8])
            return jsonify({"status": "ok", "data": cached, "meta": {"source": "cache"}}), 200

        try:
            ai_recipes = _generate_ai_recipes(ingredients, prefs)
        except (requests.exceptions.Timeout, requests.exceptions.HTTPError) as e:
            logger.warning("AI generation failed (%s) — falling back to DB", e)
            ai_recipes = []
        except (json.JSONDecodeError, KeyError, IndexError) as e:
            logger.warning("AI response parse error (%s) — falling back to DB", e)
            ai_recipes = []

        if ai_recipes:
            _cache_set(fingerprint, ai_recipes)
            return jsonify({"status": "ok", "data": ai_recipes, "meta": {"source": "ai"}}), 200

        # ── DB fallback if AI fails ───────────────────────────────────────────
        placeholders = ','.join('?' * len(ingredients))
        rows = query(f"""
            SELECT DISTINCT r.*, n.calories, n.protein, n.carbs, n.fat
            FROM recipes r
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            JOIN recipe_ingredients ri ON ri.recipe_id = r.id
            JOIN ingredients i ON i.id = ri.ingredient_id
            WHERE LOWER(i.name) IN ({placeholders})
            ORDER BY r.id
        """, ingredients)

        result = []
        for r in rows:
            nutrition = {
                "calories": r.get('calories') or 0,
                "protein":  r.get('protein')  or 0,
                "carbs":    r.get('carbs')    or 0,
                "fat":      r.get('fat')      or 0,
            }
            result.append(_recipe_row_to_dict(r, nutrition=nutrition))

        logger.info("DB fallback returned %d recipes", len(result))
        return jsonify({"status": "ok", "data": result, "meta": {"source": "db"}}), 200

    except (ValueError, TypeError) as e:
        return jsonify({"status": "error", "message": f"Invalid params: {e}"}), 400
    except Exception as e:
        logger.exception("get_recipes error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/recipe/<int:recipe_id>', methods=['GET'])
def get_recipe(recipe_id):
    """GET /api/recipe/<id> — full detail. Negative IDs = AI-generated (not in DB)."""
    try:
        # AI-generated recipes have negative IDs — can't fetch from DB
        if recipe_id < 0:
            return jsonify({"status": "error", "message": "AI recipe detail not available. Use the data from the results list."}), 404

        rows = query("""
            SELECT r.*, n.calories, n.protein, n.carbs, n.fat
            FROM recipes r
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            WHERE r.id = ?
        """, (recipe_id,))

        if not rows:
            return jsonify({"status": "error", "message": "Recipe not found"}), 404

        r        = rows[0]
        ing_rows = query("""
            SELECT i.name, ri.amount
            FROM recipe_ingredients ri
            JOIN ingredients i ON i.id = ri.ingredient_id
            WHERE ri.recipe_id = ?
        """, (recipe_id,))

        nutrition   = {"calories": r.get('calories') or 0, "protein": r.get('protein') or 0,
                       "carbs": r.get('carbs') or 0, "fat": r.get('fat') or 0}
        ingredients = [{"name": i['name'], "amount": i['amount']} for i in ing_rows]

        return jsonify({
            "status": "ok",
            "data": _recipe_row_to_dict(r, nutrition=nutrition, ingredients=ingredients),
        }), 200

    except Exception as e:
        logger.exception("get_recipe error for id=%d", recipe_id)
        return jsonify({"status": "error", "message": "Internal error."}), 500
