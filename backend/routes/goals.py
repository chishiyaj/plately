from flask import Blueprint, request, jsonify
import math

bp = Blueprint('goals', __name__)


def _mifflin_st_jeor(weight_kg: float, height_cm: float, age: int, sex: str) -> float:
    """Returns BMR in kcal/day using Mifflin-St Jeor equation."""
    if sex.lower() == 'female':
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    return bmr


def _tdee(bmr: float, activity: str = 'moderate') -> float:
    """Apply activity multiplier."""
    multipliers = {
        'sedentary':  1.2,
        'light':      1.375,
        'moderate':   1.55,
        'active':     1.725,
        'very_active': 1.9,
    }
    return bmr * multipliers.get(activity, 1.55)


@bp.route('/api/goals', methods=['POST'])
def set_goals():
    """
    POST body: {
        "weight": 70,        # kg
        "height": 175,       # cm
        "age": 20,
        "sex": "male",       # "male" | "female"
        "goal": "maintain",  # "lose" | "maintain" | "gain"
        "activity": "moderate"
    }
    Returns calorie target and protein target.
    """
    try:
        data = request.json or {}

        required = ['weight', 'height', 'age', 'sex', 'goal']
        for field in required:
            if field not in data:
                return jsonify({"status": "error", "message": f"{field} required"}), 400

        weight   = float(data['weight'])
        height   = float(data['height'])
        age      = int(data['age'])
        sex      = str(data['sex'])
        goal     = str(data['goal'])
        activity = str(data.get('activity', 'moderate'))

        bmr  = _mifflin_st_jeor(weight, height, age, sex)
        tdee = _tdee(bmr, activity)

        goal_adjustments = {
            'lose':     -500,
            'maintain': 0,
            'gain':     +300,
        }
        calorie_target = math.ceil(tdee + goal_adjustments.get(goal, 0))

        # Protein: 1.6-2.2g/kg for active students; use 2g/kg as default
        protein_target = math.ceil(weight * 2.0)

        return jsonify({
            "status": "ok",
            "data": {
                "bmr":            round(bmr),
                "tdee":           round(tdee),
                "calorie_target": calorie_target,
                "protein_target": protein_target,
                "goal":           goal,
            },
        }), 200

    except (ValueError, TypeError) as e:
        return jsonify({"status": "error", "message": f"Invalid input: {e}"}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
