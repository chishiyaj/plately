"""
routes/scan.py — Ingredient detection via free AI (OpenRouter Gemma 3).
Replaces Google Vision + Imagga entirely — zero billing required.
Flow: base64 image → AI vision prompt → ingredient list matched against DB.
Falls back to mock if OPENROUTER_API_KEY not set.
"""

from flask import Blueprint, request, jsonify
from database import query
from app import limiter
import os, base64, json, requests, logging

bp     = Blueprint('scan', __name__)
logger = logging.getLogger(__name__)

# ~5MB base64 cap
_MAX_B64_LEN = 5 * 1024 * 1024

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Model priority list — first available (non-429) is used
MODELS = [
    "google/gemma-3-12b-it:free",   # primary — reliably available
    "google/gemma-3-27b-it:free",   # fallback
    "google/gemma-4-31b-it:free",   # fallback (often rate-limited)
]


def _known_ingredients() -> list:
    return [r['name'].lower() for r in query("SELECT name FROM ingredients")]


def _call_openrouter(model: str, base64_image: str, prompt: str, key: str) -> dict:
    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://plately.app",
            "X-Title": "Plately",
        },
        json={
            "model": model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            },
                        },
                        {
                            "type": "text",
                            "text": prompt,
                        },
                    ],
                }
            ],
            "max_tokens": 300,
        },
        timeout=25,
    )
    return resp


def _ai_detect(base64_image: str) -> list[str]:
    """Send image to Gemma vision and return detected food ingredients."""
    key = os.getenv("OPENROUTER_API_KEY", "")
    if not key:
        return []

    # NOTE: Do NOT pass the known ingredient list in the prompt — it biases the
    # model to hallucinate items from the list rather than describing the image.
    prompt = (
        "You are a food ingredient detector. Look carefully at this image.\n"
        "List ONLY the raw food ingredients you can CLEARLY SEE in the image.\n"
        "Rules:\n"
        "- Only include ingredients that are VISUALLY PRESENT\n"
        "- Do NOT guess sauces, spices, or condiments unless a bottle/jar/label is clearly visible\n"
        "- Name specific items (e.g. 'salmon', 'broccoli', 'egg') — never use vague terms\n"
        "- Use simple common English names\n"
        "- If unsure about an ingredient, leave it out\n"
        "Return ONLY a JSON array of strings. No explanation, no markdown, no extra text.\n"
        "Example: [\"salmon\", \"lemon\", \"dill\"]\n"
        "Example: [\"eggs\", \"bacon\", \"bread\"]"
    )

    # Try each model in priority order, skip 429s
    resp = None
    used_model = None
    for model in MODELS:
        try:
            r = _call_openrouter(model, base64_image, prompt, key)
            if r.status_code == 429:
                logger.warning("Model %s rate-limited, trying next", model)
                continue
            r.raise_for_status()
            resp = r
            used_model = model
            break
        except requests.exceptions.HTTPError as e:
            if "429" in str(e):
                continue
            raise

    if resp is None:
        raise requests.exceptions.HTTPError("All models rate-limited")

    logger.info("Used model: %s", used_model)
    raw = resp.json()["choices"][0]["message"]["content"].strip()

    # Strip markdown fences if model adds them
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    detected = json.loads(raw)
    if not isinstance(detected, list):
        return []

    # Normalise to lowercase strings
    items = [str(i).lower().strip() for i in detected if i]
    logger.info("AI raw detection: %s", items)

    # Match against DB ingredients
    known = _known_ingredients()
    known_set = set(known)
    matched = []
    for item in items:
        # Exact match first
        if item in known_set and item not in matched:
            matched.append(item)
            continue
        # Partial match — "chicken breast" → "chicken", "green onion" → "onion"
        for ingredient in known:
            if (ingredient in item or item in ingredient) and ingredient not in matched:
                matched.append(ingredient)
                break

    # If nothing matched DB but AI returned valid food items, use raw AI output
    if not matched and items:
        matched = items[:6]

    logger.info("AI scan final: %s", matched)
    return matched


@bp.route('/api/scan', methods=['POST'])
@limiter.limit("20 per minute")
def scan():
    try:
        data         = request.json or {}
        base64_image = (data.get('image_base64') or '').strip()

        if not base64_image:
            return jsonify({"status": "error", "message": "image_base64 required"}), 400

        if len(base64_image) > _MAX_B64_LEN:
            return jsonify({"status": "error", "message": "Image too large (max 5MB)"}), 413

        # Validate base64
        try:
            base64.b64decode(base64_image, validate=True)
        except Exception:
            return jsonify({"status": "error", "message": "Invalid base64 image data"}), 400

        # No API key — return mock for dev
        if not os.getenv("OPENROUTER_API_KEY", ""):
            logger.warning("OPENROUTER_API_KEY not set — returning mock ingredients")
            return jsonify({"status": "ok", "data": {"ingredients": ["chicken", "eggs", "garlic"]}}), 200

        try:
            ingredients = _ai_detect(base64_image)
        except requests.exceptions.Timeout:
            logger.warning("AI scan timeout — returning empty")
            return jsonify({"status": "ok", "data": {"ingredients": []},
                            "message": "Scan timed out — please add ingredients manually."}), 200
        except (json.JSONDecodeError, KeyError, IndexError, ValueError) as e:
            logger.warning("AI scan parse error (%s) — returning empty", e)
            return jsonify({"status": "ok", "data": {"ingredients": []},
                            "message": "Could not read image — please add ingredients manually."}), 200
        except requests.exceptions.HTTPError as e:
            logger.error("AI scan HTTP error: %s", e)
            return jsonify({"status": "ok", "data": {"ingredients": []},
                            "message": "AI unavailable — please add ingredients manually."}), 200

        return jsonify({"status": "ok", "data": {"ingredients": ingredients}}), 200

    except Exception:
        logger.exception("Unexpected scan error")
        return jsonify({"status": "error", "message": "Internal error."}), 500
