"""routes/history.py"""
from flask import Blueprint, request, jsonify
from database import query, execute
import logging

bp     = Blueprint('history', __name__)
logger = logging.getLogger(__name__)


@bp.route('/api/history', methods=['GET'])
def get_history():
    try:
        user_id = request.args.get('user_id', 'default')
        rows = query("""
            SELECT * FROM history WHERE user_id = ?
            ORDER BY timestamp DESC LIMIT 50
        """, (user_id,))
        return jsonify({"status": "ok", "data": rows}), 200
    except Exception:
        logger.exception("get_history error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/history', methods=['POST'])
def add_history():
    try:
        data             = request.json or {}
        user_id          = (data.get('user_id') or 'default').strip()
        action_type      = (data.get('action_type') or 'cooked').strip()
        ingredient_names = (data.get('ingredient_names') or '').strip()
        recipe_count     = max(0, int(data.get('recipe_count', 1)))

        # Sanitise action_type to known values
        if action_type not in ('cooked', 'scanned', 'typed', 'browsed'):
            action_type = 'cooked'

        execute(
            "INSERT INTO history (user_id, action_type, ingredient_names, recipe_count) VALUES (?,?,?,?)",
            (user_id, action_type, ingredient_names[:500], recipe_count),
        )
        return jsonify({"status": "ok", "data": {"logged": True}}), 200
    except (ValueError, TypeError) as e:
        return jsonify({"status": "error", "message": f"Invalid input: {e}"}), 400
    except Exception:
        logger.exception("add_history error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/history/stats', methods=['GET'])
def get_history_stats():
    try:
        user_id = request.args.get('user_id', 'default')
        total = query(
            "SELECT COUNT(*) as c, COALESCE(SUM(recipe_count),0) as r FROM history WHERE user_id = ?",
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
    except Exception:
        logger.exception("get_history_stats error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/history/<int:history_id>', methods=['DELETE'])
def delete_history_entry(history_id):
    try:
        # Require user_id so users can only delete their own entries
        user_id = request.args.get('user_id', 'default')
        execute("DELETE FROM history WHERE id = ? AND user_id = ?", (history_id, user_id))
        return jsonify({"status": "ok", "data": {"deleted": True}}), 200
    except Exception:
        logger.exception("delete_history error")
        return jsonify({"status": "error", "message": "Internal error."}), 500


@bp.route('/api/history', methods=['DELETE'])
def clear_history():
    try:
        user_id = request.args.get('user_id', 'default')
        execute("DELETE FROM history WHERE user_id = ?", (user_id,))
        return jsonify({"status": "ok", "data": {"cleared": True}}), 200
    except Exception:
        logger.exception("clear_history error")
        return jsonify({"status": "error", "message": "Internal error."}), 500
