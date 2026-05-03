"""
routes/chat.py — AI Chat endpoint.
Rate limited aggressively (protects OpenRouter free-tier credits).
Message capped at 500 chars. Accepts optional history for multi-turn conversation.
"""

from flask import Blueprint, request, jsonify
from app import limiter
import os
import time
import logging
import requests

bp     = Blueprint("chat", __name__)
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL          = "google/gemma-3-12b-it:free"
MAX_MSG_LEN    = 500
MAX_HISTORY    = 6   # keep last N exchanges (N/2 turns each)
CACHE_TTL      = 3600

SYSTEM_PROMPT = """You are Plately, a friendly and knowledgeable AI cooking assistant built for budget-conscious students in the Philippines.

YOUR PERSONALITY:
- Warm, encouraging, and practical
- You always mention protein content (students track macros)
- Prices are always in Philippine pesos (₱), realistic for a student budget
- Keep replies concise — under 220 words unless a meal plan is requested

STRICT TOPIC RULE:
You ONLY answer questions about: cooking, recipes, ingredients, nutrition, meal planning, and food budgeting.
If asked about anything else, say: "I'm Plately, your cooking assistant! I can only help with food and nutrition topics."

NEVER USE: markdown symbols (**, ##, *, `, ~~), HTML tags, or emojis.

RESPONSE FORMATS — match the format to the question type:

FOR RECIPE SUGGESTIONS ("what can I cook with X?", "give me meal ideas"):
Start with one short sentence.
Then list recipes like:
1. [Recipe Name] — [Cook time] — [Protein]g protein — ~₱[cost]
2. ...
End with: "Want the full steps for any of these?"

FOR COOKING STEPS ("how do I make X?", "steps for Y"):
One intro sentence. Then numbered steps, each on its own line:
1. [Step]
2. [Step]
End with a brief tip.

FOR NUTRITION QUESTIONS ("how much protein in X?", "is Y healthy?"):
One direct answer sentence first.
Then 2 supporting facts, each starting with a dash:
- [Fact 1]
- [Fact 2]

FOR SUBSTITUTIONS ("I don't have X, what can I use?"):
"You can substitute X with: [option 1], [option 2], or [option 3]."
Then one line on how each option changes the dish.

FOR MEAL PLANS ("plan my meals for the week"):
Label each day clearly. One meal per line:
Monday: [Breakfast] / [Lunch] / [Dinner]
Tuesday: ...
Include estimated protein for each day at the end.

FOR INGREDIENT MATCHING ("what can I make with chicken, eggs, and garlic?"):
List 3 recipes with protein content and estimated cost. Keep it short.

FOR GENERAL COOKING TIPS ("how do I not overcook pasta?"):
Give a direct answer in 2-4 sentences. Include one pro tip.

ALWAYS: mention protein content somewhere in every reply."""

# TTL-aware cache: {message: (reply, timestamp)} — only for single-turn (no history)
_cache: dict[str, tuple[str, float]] = {}


def _get_cached(message: str) -> str | None:
    if message in _cache:
        reply, ts = _cache[message]
        if time.monotonic() - ts < CACHE_TTL:
            return reply
        del _cache[message]
    return None


def _set_cached(message: str, reply: str) -> None:
    if len(_cache) >= 200:
        oldest = min(_cache, key=lambda k: _cache[k][1])
        del _cache[oldest]
    _cache[message] = (reply, time.monotonic())


def _build_messages(message: str, history: list) -> list:
    """Build OpenRouter messages array with system prompt + optional history."""
    msgs = [{"role": "user", "content": f"{SYSTEM_PROMPT}\n\nUser question: {message}"}]

    if not history:
        return msgs

    # history format: [{role: 'user'|'assistant', content: str}, ...]
    # Trim to last MAX_HISTORY messages
    trimmed = history[-MAX_HISTORY:]

    # Build: system context + history + current message
    msgs = [{"role": "user", "content": SYSTEM_PROMPT}]
    for h in trimmed:
        role    = h.get("role", "user")
        content = str(h.get("content", ""))[:500]
        if role in ("user", "assistant") and content:
            msgs.append({"role": role, "content": content})
    msgs.append({"role": "user", "content": message})
    return msgs


def _ask_ai(message: str, history: list) -> str:
    # Only use cache when no history (single-turn)
    if not history:
        cached = _get_cached(message)
        if cached:
            return cached

    key = os.getenv("OPENROUTER_API_KEY", "")
    if not key:
        logger.warning("OPENROUTER_API_KEY not set — returning fallback response")
        return (
            "Here are 3 quick high-protein meal ideas for students:\n"
            "1. Chicken Stir Fry — 20 min — 38g protein — ~₱150\n"
            "2. Egg Fried Rice — 15 min — 22g protein — ~₱80\n"
            "3. Tuna Pasta — 18 min — 34g protein — ~₱120\n\n"
            "Want the full steps for any of these?"
        )

    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://plately.app",
            "X-Title": "Plately",
        },
        json={
            "model": MODEL,
            "messages": _build_messages(message, history),
            "max_tokens": 450,
        },
        timeout=20,
    )
    resp.raise_for_status()
    reply = resp.json()["choices"][0]["message"]["content"].strip()
    reply = reply.replace("**", "").replace("##", "").replace("```", "")

    if not history:
        _set_cached(message, reply)
    logger.info("AI reply generated (%d chars)", len(reply))
    return reply


@bp.route("/api/chat", methods=["POST"])
@limiter.limit("10 per minute")
def chat():
    try:
        data    = request.json or {}
        message = (data.get("message") or "").strip()
        history = data.get("history") or []   # [{role, content}, ...] — last N messages

        if not message:
            return jsonify({"status": "error", "message": "message required"}), 400

        if len(message) > MAX_MSG_LEN:
            message = message[:MAX_MSG_LEN]
        message = "".join(c for c in message if c >= " " or c in "\n\t")

        # Validate history format — ignore malformed entries
        if not isinstance(history, list):
            history = []
        history = [h for h in history if isinstance(h, dict) and "role" in h and "content" in h]

        reply = _ask_ai(message, history)
        return jsonify({"status": "ok", "data": {"reply": reply}}), 200

    except requests.exceptions.Timeout:
        logger.warning("OpenRouter timeout")
        return jsonify({"status": "error", "message": "AI timed out. Try again."}), 504
    except requests.exceptions.HTTPError as e:
        logger.error("OpenRouter HTTP error: %s", e)
        return jsonify({"status": "error", "message": "AI service error."}), 502
    except Exception:
        logger.exception("Unexpected chat error")
        return jsonify({"status": "error", "message": "Internal error."}), 500
