from flask import Blueprint, request, jsonify
import os
import requests

bp = Blueprint('scan', __name__)

VISION_KEY = os.getenv('GOOGLE_VISION_API_KEY', '')
VISION_URL = 'https://vision.googleapis.com/v1/images:annotate'


def _known_ingredients():
    from database import query
    rows = query("SELECT name FROM ingredients")
    return {r['name'].lower() for r in rows}


@bp.route('/api/scan', methods=['POST'])
def scan():
    try:
        data = request.json or {}
        base64_image = data.get('image_base64', '')
        if not base64_image:
            return jsonify({"status": "error", "message": "image_base64 required"}), 400

        if not VISION_KEY:
            # Fallback: return mock ingredients when no API key
            return jsonify({"status": "ok", "data": {"ingredients": ["chicken", "eggs", "garlic"]}}), 200

        res = requests.post(
            f'{VISION_URL}?key={VISION_KEY}',
            json={
                'requests': [{
                    'image': {'content': base64_image},
                    'features': [{'type': 'LABEL_DETECTION', 'maxResults': 20}],
                }]
            },
            timeout=10,
        )
        res.raise_for_status()
        labels = [
            a['description'].lower()
            for a in res.json()['responses'][0].get('labelAnnotations', [])
        ]

        known = _known_ingredients()
        matched = [l for l in labels if l in known]

        return jsonify({"status": "ok", "data": {"ingredients": matched}}), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
