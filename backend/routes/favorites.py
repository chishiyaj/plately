"""routes/favorites.py"""
from flask import Blueprint, request, jsonify
from database import query, execute, PLACEHOLDER as ph
import logging

bp     = Blueprint('favorites', __name__)
logger = logging.getLogger(__name__)


def _recipe_with_nutrition_and_ingredients(r, ing_rows) -> dict:
    return {
        "id":           r['id'],
        "name":         r['name'],
        "cook_time":    r['cook_time'],
        "difficulty":   r['difficulty'],
        "instructions": r['instructions'],
        "tags":         r.get('tags', ''),
        "nutrition": {
            "calories": r.get('calories') or 0,
            "protein":  r.get('protein')  or 0,
            "carbs":    r.get('carbs')    or 0,
            "fat":      r.get('fat')      or 0,
            "cost_php": r.get('cost_php') or 0,
        },
        "image_url":  r.get('image_url', ''),
        "ingredients": [{"name": i['name'], "amount": i['amount']} for i in ing_rows],
    }


@bp.route('/api/favorites', methods=['GET'])
def get_favorites():
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query(f"""
            SELECT r.*, n.calories, n.protein, n.carbs, n.fat, n.cost_php
            FROM favorites f
            JOIN recipes r ON r.id = f.recipe_id
            LEFT JOIN nutrition n ON n.recipe_id = r.id
            WHERE f.user_id = {ph}
            ORDER BY f.id DESC
        """, (user_id,))

        result = []
        for r in rows:
            ing_rows = query(f"""
                SELECT i.name, ri.amount
                FROM recipe_ingredients ri
                JOIN ingredients i ON i.id = ri.ingredient_id
                WHERE ri.recipe_id = {ph}
            """, (r['id'],))
            result.append(_recipe_with_nutrition_and_ingredients(r, ing_rows))

        return jsonify({"status": "ok", "data": result}), 200
    except Exception:
        logger.exception("get_favorites error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/favorites', methods=['POST'])
def add_favorite():
    try:
        data      = request.json or {}
        user_id   = (data.get('user_id') or 'default').strip()
        recipe_id = data.get('recipe_id')
        if recipe_id is None:
            return jsonify({"status": "error", "message": "recipe_id required"}), 400
        try:
            recipe_id = int(recipe_id)
        except (ValueError, TypeError):
            return jsonify({"status": "error", "message": "recipe_id must be an integer"}), 400
        if recipe_id <= 0:
            return jsonify({"status": "error", "message": "recipe_id must be a positive integer"}), 400
        execute(
            f"INSERT INTO favorites (user_id, recipe_id) VALUES ({ph},{ph}) ON CONFLICT DO NOTHING",
            (user_id, recipe_id),
        )
        return jsonify({"status": "ok", "data": {"saved": True}}), 200
    except (ValueError, TypeError):
        return jsonify({"status": "error", "message": "Invalid recipe_id"}), 400
    except Exception:
        logger.exception("add_favorite error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/favorites/<int:recipe_id>', methods=['DELETE'])
def remove_favorite(recipe_id):
    try:
        user_id = request.args.get('user_id', 'default')
        execute(f"DELETE FROM favorites WHERE user_id = {ph} AND recipe_id = {ph}", (user_id, recipe_id))
        return jsonify({"status": "ok", "data": {"removed": True}}), 200
    except Exception:
        logger.exception("remove_favorite error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/favorites/check/<int:recipe_id>', methods=['GET'])
def check_favorite(recipe_id):
    try:
        user_id = request.args.get('user_id', 'default')
        rows    = query(
            f"SELECT id FROM favorites WHERE user_id = {ph} AND recipe_id = {ph}",
            (user_id, recipe_id),
        )
        return jsonify({"status": "ok", "data": {"is_favorite": len(rows) > 0}}), 200
    except Exception:
        logger.exception("check_favorite error")
        return jsonify({"status": "error", "message": "Internal error."}), 500
