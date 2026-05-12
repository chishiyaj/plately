"""
routes/chat.py — AI Chat endpoint.
Rate limited aggressively (protects OpenRouter free-tier credits).
Message capped at 500 chars. Accepts optional history for multi-turn conversation.
"""

from flask import Blueprint, request, jsonify
from flask_limiter.util import get_remote_address
from app import limiter
import os
import time
import logging
import requests

bp     = Blueprint("chat", __name__)
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL          = "google/gemma-3-27b-it:free"
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

NEVER USE: HTML tags or emojis. You MAY use markdown: **bold** for recipe names and key numbers, numbered lists for steps, bullet points (-) for facts and ingredients. No headers (##). Keep it clean and readable.

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
    """Build OpenRouter messages array with system prompt + optional history.

    Gemma constraint: no two consecutive messages with the same role.
    Strategy: merge system prompt into the FIRST user message so we never
    have a bare system-role entry, then interleave history strictly alternating
    user/assistant. If history order is broken, drop the offending entry.
    """
    if not history:
        # Single-turn: system + question merged into one user message
        return [{"role": "user", "content": f"{SYSTEM_PROMPT}\n\nUser question: {message}"}]

    # Trim to last MAX_HISTORY messages
    trimmed = history[-MAX_HISTORY:]

    # Filter to only valid roles and remove consecutive duplicates
    valid = []
    for h in trimmed:
        role    = h.get("role", "user")
        content = str(h.get("content", ""))[:500].strip()
        if role not in ("user", "assistant") or not content:
            continue
        # Drop if same role as last entry (Gemma rejects consecutive same-role)
        if valid and valid[-1]["role"] == role:
            continue
        valid.append({"role": role, "content": content})

    # Build final array: system merged into first message, then history, then current
    msgs = []
    if valid and valid[0]["role"] == "user":
        # Merge system prompt into the first historical user message
        msgs.append({"role": "user", "content": f"{SYSTEM_PROMPT}\n\n{valid[0]['content']}"})
        rest = valid[1:]
    else:
        # History starts with assistant — prepend a synthetic user+system turn
        msgs.append({"role": "user", "content": SYSTEM_PROMPT})
        rest = valid

    for h in rest:
        # Ensure no consecutive same-role after prepend
        if msgs and msgs[-1]["role"] == h["role"]:
            continue
        msgs.append(h)

    # Append current user message — ensure it doesn't follow another user msg
    if msgs and msgs[-1]["role"] == "user":
        # Merge into last user message rather than create consecutive user entries
        msgs[-1]["content"] = f"{msgs[-1]['content']}\n\n{message}"
    else:
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
            "max_tokens": 600,
        },
        timeout=20,
    )
    logger.info("OpenRouter status: %d", resp.status_code)
    if resp.status_code != 200:
        # Log the full error body so Railway logs show what went wrong
        logger.error("OpenRouter error body: %s", resp.text[:500])
        resp.raise_for_status()
    resp_json = resp.json()
    # Guard against unexpected response shapes
    choices = resp_json.get("choices")
    if not choices:
        logger.error("OpenRouter returned no choices: %s", str(resp_json)[:300])
        raise ValueError(f"OpenRouter returned empty choices: {str(resp_json)[:200]}")
    reply = choices[0]["message"]["content"].strip()
    logger.info("Raw OpenRouter chat response (first 200 chars): %s", reply[:200])
    # Strip only code fences and HTML — keep ** and bullet markdown (rendered by MarkdownBody)
    reply = reply.replace("```", "").replace("<br>", "\n").strip()

    if not history:
        _set_cached(message, reply)
    logger.info("AI reply generated (%d chars)", len(reply))
    return reply


def _get_user_id() -> str:
    """Rate limit key: use Firebase UID from request body, fall back to IP.
    Prevents all users sharing one IP (Railway NAT) from hitting the same bucket."""
    try:
        data = request.get_json(silent=True) or {}
        uid = str(data.get("user_id", "")).strip()
        if uid and uid != "anonymous":
            return uid
    except Exception:
        pass
    return get_remote_address()


@bp.route("/api/chat", methods=["POST"])
@limiter.limit("15 per minute", key_func=_get_user_id)
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
        # Surface the actual HTTP status + body for easier diagnosis
        body = ""
        try:
            body = e.response.text[:200] if e.response is not None else ""
        except Exception:
            pass
        logger.error("OpenRouter HTTP error: %s — body: %s", e, body)
        return jsonify({"status": "error", "message": f"AI service error ({e.response.status_code if e.response else 'unknown'}). {body}"}), 502
    except ValueError as e:
        logger.error("OpenRouter response parse error: %s", e)
        return jsonify({"status": "error", "message": f"AI response error: {e}"}), 502
    except Exception as e:
        logger.exception("Unexpected chat error")
        return jsonify({"status": "error", "message": f"Internal error: {type(e).__name__}: {str(e)[:120]}"}), 500
