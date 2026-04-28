from flask import Blueprint, request, jsonify
import os
import requests

bp = Blueprint('chat', __name__)

OPENROUTER_KEY = os.getenv('OPENROUTER_API_KEY', '')
OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'
MODEL           = 'mistralai/mistral-7b-instruct:free'

SYSTEM_PROMPT = (
    "You are Plately, a helpful AI cooking assistant for students. "
    "Focus on high-protein, affordable, quick recipes. "
    "Keep replies concise (2-4 sentences max). "
    "Always mention protein content and approx cost when recommending recipes. "
    "Use simple language — no fancy culinary jargon."
)

# Simple in-memory cache for identical messages (MVP only)
_cache: dict = {}


def _ask_ai(message: str) -> str:
    if message in _cache:
        return _cache[message]

    if not OPENROUTER_KEY:
        return (
            "I'd suggest a high-protein chicken and vegetable stir fry — "
            "quick (20 min), packed with 38g protein, and only about ₱150 per serving. "
            "Want the full recipe?"
        )

    res = requests.post(
        OPENROUTER_URL,
        headers={
            'Authorization': f'Bearer {OPENROUTER_KEY}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://plately.app',
            'X-Title': 'Plately',
        },
        json={
            'model': MODEL,
            'messages': [
                {'role': 'system', 'content': SYSTEM_PROMPT},
                {'role': 'user',   'content': message},
            ],
            'max_tokens': 300,
        },
        timeout=15,
    )
    res.raise_for_status()
    reply = res.json()['choices'][0]['message']['content'].strip()
    _cache[message] = reply
    return reply


@bp.route('/api/chat', methods=['POST'])
def chat():
    try:
        data = request.json or {}
        message = (data.get('message') or '').strip()

        if not message:
            return jsonify({"status": "error", "message": "message required"}), 400

        reply = _ask_ai(message)
        return jsonify({"status": "ok", "data": {"reply": reply}}), 200

    except requests.exceptions.Timeout:
        return jsonify({"status": "error", "message": "AI response timed out. Try again."}), 504
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
