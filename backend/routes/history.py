from flask import Blueprint, request, jsonify
from database import query, execute

bp = Blueprint('history', __name__)


@bp.route('/api/history', methods=['GET'])
def get_history():
    """GET /api/history?user_id=default"""
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query("""
            SELECT * FROM history
            WHERE user_id = ?
            ORDER BY timestamp DESC
            LIMIT 50
        """, (user_id,))
        return jsonify({"status": "ok", "data": rows}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/history', methods=['POST'])
def add_history():
    """POST /api/history — body: {user_id, action_type, ingredient_names, recipe_count}"""
    try:
        data = request.json or {}
        user_id          = data.get('user_id', 'default')
        action_type      = data.get('action_type', 'cooked')
        ingredient_names = data.get('ingredient_names', '')
        recipe_count     = int(data.get('recipe_count', 1))

        execute(
            "INSERT INTO history (user_id, action_type, ingredient_names, recipe_count) VALUES (?,?,?,?)",
            (user_id, action_type, ingredient_names, recipe_count)
        )
        return jsonify({"status": "ok", "data": {"logged": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/history/stats', methods=['GET'])
def get_history_stats():
    """GET /api/history/stats?user_id=default — aggregated stats for profile screen"""
    try:
        user_id = request.args.get('user_id', 'default')

        total = query(
            "SELECT COUNT(*) as c, SUM(recipe_count) as r FROM history WHERE user_id = ?",
            (user_id,)
        )
        week = query(
            "SELECT COUNT(*) as c FROM history WHERE user_id = ? AND timestamp >= datetime('now','-7 days')",
            (user_id,)
        )
        return jsonify({"status": "ok", "data": {
            "total_sessions":     total[0]['c'] if total else 0,
            "total_recipes":      total[0]['r'] if total else 0,
            "sessions_this_week": week[0]['c']  if week  else 0,
        }}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/history/<int:history_id>', methods=['DELETE'])
def delete_history_entry(history_id):
    """DELETE /api/history/<id> — delete a single history entry"""
    try:
        execute("DELETE FROM history WHERE id = ?", (history_id,))
        return jsonify({"status": "ok", "data": {"deleted": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/api/history', methods=['DELETE'])
def clear_history():
    """DELETE /api/history?user_id=default — clear all history for a user"""
    try:
        user_id = request.args.get('user_id', 'default')
        execute("DELETE FROM history WHERE user_id = ?", (user_id,))
        return jsonify({"status": "ok", "data": {"cleared": True}}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
