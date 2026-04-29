from flask import Blueprint, request, jsonify
from database import query, execute

bp = Blueprint('favorites', __name__)


def _recipe_with_nutrition(r):
    return {
        "id":           r['id'],
        "name":         r['name'],
        "cook_time":    r['cook_time'],
        "difficulty":   r['difficulty'],
        "instructions": r['instructions'],
        "tags":         r.get('tags', ''),
        "nutrition": {
            "calories": r.get('calories', 0),
            "protein":  r.get('protein', 0),
            "carbs":    r.get('carbs', 0),
            "fat":      r.get('fat', 0),
        },
    }


@bp.route('/api/favorites', methods=['GET'])
def get_favorites():
    """GET /api/favorites?user_id=default"""
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query("""
            SELECT r.*, n.calories, n.protein, n.carbs, n.fat
            FROM favorites f
            JOIN recipes r ON r.id = f.recipe_id
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            WHERE f.user_id = ?
            ORDER BY f.id DESC
        """, (user_id,))
        return jsonify({"status": "ok", "data": [_recipe_with_nutrition(r) for r in rows]}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/favorites', methods=['POST'])
def add_favorite():
    """POST /api/favorites — body: {user_id, recipe_id}"""
    try:
        data = request.json or {}
        user_id   = data.get('user_id', 'default')
        recipe_id = data.get('recipe_id')
        if not recipe_id:
            return jsonify({"status": "error", "message": "recipe_id required"}), 400
        execute(
            "INSERT OR IGNORE INTO favorites (user_id, recipe_id) VALUES (?,?)",
            (user_id, recipe_id)
        )
        return jsonify({"status": "ok", "data": {"saved": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/favorites/<int:recipe_id>', methods=['DELETE'])
def remove_favorite(recipe_id):
    """DELETE /api/favorites/<recipe_id>?user_id=default"""
    try:
        user_id = request.args.get('user_id', 'default')
        execute(
            "DELETE FROM favorites WHERE user_id = ? AND recipe_id = ?",
            (user_id, recipe_id)
        )
        return jsonify({"status": "ok", "data": {"removed": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/favorites/check/<int:recipe_id>', methods=['GET'])
def check_favorite(recipe_id):
    """GET /api/favorites/check/<recipe_id>?user_id=default — is it saved?"""
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query(
            "SELECT id FROM favorites WHERE user_id = ? AND recipe_id = ?",
            (user_id, recipe_id)
        )
        return jsonify({"status": "ok", "data": {"is_favorite": len(rows) > 0}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
