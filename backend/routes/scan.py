"""
routes/scan.py — Ingredient detection via free AI.
Provider chain: Groq Llama 4 Scout (primary, fast) → OpenRouter Gemma 4 (fallback).
Flow: base64 image → AI vision prompt → ingredient list matched against DB.
Falls back to mock if no API keys set.
"""

from flask import Blueprint, request, jsonify
from database import query
from app import limiter
import os, base64, json, requests, logging

bp     = Blueprint('scan', __name__)
logger = logging.getLogger(__name__)

# ~5MB base64 cap
_MAX_B64_LEN = 5 * 1024 * 1024

GROQ_URL       = "https://api.groq.com/openai/v1/chat/completions"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Groq vision model — fast, free, reliable
GROQ_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

# OpenRouter fallback models
OPENROUTER_MODELS = [
    "google/gemma-4-31b-it:free",
    "google/gemma-4-26b-a4b-it:free",
]


def _known_ingredients() -> list:
    return [r['name'].lower() for r in query("SELECT name FROM ingredients")]


def _build_vision_payload(model: str, base64_image: str, prompt: str) -> dict:
    return {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ],
        "max_tokens": 300,
    }


def _call_groq(base64_image: str, prompt: str, key: str):
    return requests.post(
        GROQ_URL,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json=_build_vision_payload(GROQ_VISION_MODEL, base64_image, prompt),
        timeout=25,
    )


def _call_openrouter(model: str, base64_image: str, prompt: str, key: str):
    return requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://plately.app",
            "X-Title": "Plately",
        },
        json=_build_vision_payload(model, base64_image, prompt),
        timeout=25,
    )


def _ai_detect(base64_image: str) -> list[str]:
    """Send image to vision AI and return detected food ingredients.
    Provider chain: Groq (primary) → OpenRouter Gemma 4 (fallback).
    """
    groq_key       = os.getenv("GROQ_API_KEY", "").strip()
    openrouter_key = os.getenv("OPENROUTER_API_KEY", "").strip()

    if not groq_key and not openrouter_key:
        return []

    prompt = (
        "You are a food ingredient detector for a cooking app. Look carefully at this image.\n"
        "Identify ALL food items and ingredients you can see — including raw ingredients, "
        "whole foods, packaged goods, and cooked dishes.\n"
        "Be thorough: common items like eggs, bread, rice, fruit, vegetables, and meat "
        "should always be named if visible.\n"
        "Rules:\n"
        "- Name specific items: 'egg' not 'food item', 'chicken breast' not 'meat'\n"
        "- Include individual whole foods (e.g. a single egg, a banana, an onion)\n"
        "- Use simple common English names\n"
        "- Do NOT include non-food items (plates, utensils, countertops)\n"
        "- If you see a cooked dish, list its likely main ingredients\n"
        "Return ONLY a JSON array of strings. No explanation, no markdown, no extra text.\n"
        "Example: [\"eggs\", \"bacon\", \"bread\"]\n"
        "Example: [\"chicken breast\", \"broccoli\", \"garlic\", \"olive oil\"]"
    )

    resp = None
    used_model = None

    # 1. Try Groq first — fast, reliable, free
    if groq_key:
        try:
            r = _call_groq(base64_image, prompt, groq_key)
            if r.status_code == 429:
                logger.warning("Groq rate-limited, falling back to OpenRouter")
            else:
                r.raise_for_status()
                resp = r
                used_model = GROQ_VISION_MODEL
                logger.info("Scan using Groq: %s", GROQ_VISION_MODEL)
        except requests.exceptions.HTTPError as e:
            logger.warning("Groq scan error: %s — trying OpenRouter", e)

    # 2. Fallback to OpenRouter Gemma 4
    if resp is None and openrouter_key:
        for model in OPENROUTER_MODELS:
            try:
                r = _call_openrouter(model, base64_image, prompt, openrouter_key)
                if r.status_code == 429:
                    logger.warning("OpenRouter model %s rate-limited, trying next", model)
                    continue
                r.raise_for_status()
                resp = r
                used_model = model
                logger.info("Scan using OpenRouter: %s", model)
                break
            except requests.exceptions.HTTPError as e:
                if "429" in str(e):
                    continue
                raise

    if resp is None:
        raise requests.exceptions.HTTPError("All vision providers rate-limited or unavailable")

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

        # No API keys — return mock for dev
        if not os.getenv("GROQ_API_KEY", "") and not os.getenv("OPENROUTER_API_KEY", ""):
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
