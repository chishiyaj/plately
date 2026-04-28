from flask import Blueprint, request, jsonify
from database import query

bp = Blueprint('recipes', __name__)


def _recipe_row_to_dict(r, nutrition=None, ingredients=None):
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
    if ingredients:
        d['ingredients'] = ingredients
    return d


@bp.route('/api/recipes', methods=['POST'])
def get_recipes():
    """POST body: { "ingredients": ["chicken", "eggs"] }
    Returns recipes that contain at least one matching ingredient.
    """
    try:
        data = request.json or {}
        ingredients = [i.strip().lower() for i in data.get('ingredients', []) if i.strip()]

        if not ingredients:
            # Return all recipes when no ingredients provided (browse mode)
            rows = query("""
                SELECT r.*, n.calories, n.protein, n.carbs, n.fat
                FROM recipes r
                LEFT JOIN nutrition n ON n.recipe_id = r.id
                ORDER BY r.id
            """)
        else:
            # Match recipes containing any of the provided ingredients
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
                "calories": r.get('calories', 0),
                "protein":  r.get('protein', 0),
                "carbs":    r.get('carbs', 0),
                "fat":      r.get('fat', 0),
            }
            result.append(_recipe_row_to_dict(r, nutrition=nutrition))

        return jsonify({"status": "ok", "data": result}), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/recipe/<int:recipe_id>', methods=['GET'])
def get_recipe(recipe_id):
    """GET /api/recipe/<id> — full detail with ingredients list."""
    try:
        rows = query("""
            SELECT r.*, n.calories, n.protein, n.carbs, n.fat
            FROM recipes r
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            WHERE r.id = ?
        """, (recipe_id,))

        if not rows:
            return jsonify({"status": "error", "message": "Recipe not found"}), 404

        r = rows[0]

        ing_rows = query("""
            SELECT i.name, ri.amount
            FROM recipe_ingredients ri
            JOIN ingredients i ON i.id = ri.ingredient_id
            WHERE ri.recipe_id = ?
        """, (recipe_id,))

        nutrition = {
            "calories": r.get('calories', 0),
            "protein":  r.get('protein', 0),
            "carbs":    r.get('carbs', 0),
            "fat":      r.get('fat', 0),
        }
        ingredients = [{"name": i['name'], "amount": i['amount']} for i in ing_rows]

        return jsonify({
            "status": "ok",
            "data": _recipe_row_to_dict(r, nutrition=nutrition, ingredients=ingredients),
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
