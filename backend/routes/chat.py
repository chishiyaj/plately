"""
routes/chat.py — AI Chat endpoint.
Provider chain: Groq (fast, free) → OpenRouter (fallback) → smart hardcoded reply.
Rate limited per Firebase UID to protect free-tier credits.
Message capped at 500 chars. Accepts optional history for multi-turn conversation.
"""

from flask import Blueprint, request, jsonify
from flask_limiter.util import get_remote_address
from app import limiter
import os
import time
import random
import logging
import requests

bp     = Blueprint("chat", __name__)
logger = logging.getLogger(__name__)

# ── Provider URLs ─────────────────────────────────────────────────────────────
GROQ_URL        = "https://api.groq.com/openai/v1/chat/completions"
OPENROUTER_URL  = "https://openrouter.ai/api/v1/chat/completions"

# ── Model config ───────────────────────────────────────────────────────────────
# Groq models — fast, generous free tier, very reliable
GROQ_MODELS = [
    "llama-3.3-70b-versatile",   # primary — best quality on Groq
    "llama3-8b-8192",            # fallback — lighter, still very good
]

# OpenRouter models — backup when Groq is down
OPENROUTER_MODELS = [
    "meta-llama/llama-3.3-70b-instruct:free",
    "google/gemma-4-31b-it:free",
    "mistralai/mistral-7b-instruct:free",
]

MAX_MSG_LEN = 500
MAX_HISTORY = 6
CACHE_TTL   = 3600

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

# ── Smart hardcoded fallback replies ──────────────────────────────────────────
# Rotates through useful cooking tips when all AI providers are down.
# Each entry is a complete, genuinely helpful response.
_FALLBACK_REPLIES = [
    (
        "Here are 3 quick high-protein meals perfect for students:\n\n"
        "1. **Tortang Giniling** — 15 min — 28g protein — ~₱80\n"
        "2. **Egg Fried Rice** — 12 min — 22g protein — ~₱60\n"
        "3. **Tuna Omelette** — 10 min — 30g protein — ~₱75\n\n"
        "All three use pantry staples you probably already have. "
        "Want the full steps for any of these?"
    ),
    (
        "For a budget ₱100-150 high-protein meal, here's what I'd recommend:\n\n"
        "**Chicken Arroz Caldo** — 25 min — 35g protein — ~₱120\n\n"
        "1. Sauté garlic, onion, and ginger in oil\n"
        "2. Add chicken pieces, cook until browned\n"
        "3. Add 1 cup rice and 4 cups water\n"
        "4. Simmer 20 minutes, season with fish sauce and pepper\n\n"
        "Pro tip: use chicken thighs — more protein and flavor than breast at the same price."
    ),
    (
        "Here's a quick protein cheat sheet for common Filipino ingredients:\n\n"
        "- **Chicken breast** (100g) — 31g protein — ~₱70\n"
        "- **Eggs** (2 pcs) — 12g protein — ~₱20\n"
        "- **Canned tuna** (1 can) — 25g protein — ~₱35\n"
        "- **Tofu** (100g) — 8g protein — ~₱20\n"
        "- **Ground pork** (100g) — 26g protein — ~₱80\n\n"
        "Eggs + canned tuna together give you 37g protein for just ₱55 — "
        "the best budget-protein combo for students."
    ),
    (
        "Three things that make any student meal better:\n\n"
        "1. **Always add garlic** — it makes cheap ingredients taste expensive\n"
        "2. **Cook rice in broth** instead of water — zero extra cost, way more flavor\n"
        "3. **Egg everything** — cracking an egg into noodles, fried rice, or soup "
        "adds 6g protein for ₱10\n\n"
        "The highest-protein cheap meal you can make: 3 scrambled eggs + 1 can tuna "
        "on rice = **43g protein for under ₱80**."
    ),
    (
        "Quick meal prep idea for the whole week — under ₱500 total:\n\n"
        "**Sunday prep (1 hour):**\n"
        "- Cook 3 cups rice (lasts 4-5 days)\n"
        "- Boil 6 eggs (keeps in fridge 1 week)\n"
        "- Fry 500g chicken thighs with garlic and soy sauce\n\n"
        "This gives you lunch and dinner bases for 3-4 days. "
        "Just mix and match with whatever vegetables you have. "
        "Total protein per day: ~60-80g. Total cost: ~₱400-450."
    ),
]


# ── Cache ─────────────────────────────────────────────────────────────────────
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


# ── Message builder ────────────────────────────────────────────────────────────
def _build_messages(message: str, history: list) -> list:
    """Build messages array with system prompt + optional history."""
    if not history:
        return [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": message},
        ]

    trimmed = history[-MAX_HISTORY:]
    valid = []
    for h in trimmed:
        role    = h.get("role", "user")
        content = str(h.get("content", ""))[:500].strip()
        if role not in ("user", "assistant") or not content:
            continue
        if valid and valid[-1]["role"] == role:
            continue
        valid.append({"role": role, "content": content})

    msgs = [{"role": "system", "content": SYSTEM_PROMPT}]
    for h in valid:
        msgs.append(h)

    if msgs[-1]["role"] == "user":
        msgs[-1]["content"] = f"{msgs[-1]['content']}\n\n{message}"
    else:
        msgs.append({"role": "user", "content": message})

    return msgs


# ── Provider callers ───────────────────────────────────────────────────────────
def _call_groq(model: str, messages: list, key: str) -> str:
    """Call Groq API. Raises on failure."""
    resp = requests.post(
        GROQ_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type":  "application/json",
        },
        json={"model": model, "messages": messages, "max_tokens": 600},
        timeout=15,
    )
    logger.info("Groq [%s] status: %d", model, resp.status_code)
    if resp.status_code != 200:
        logger.error("Groq [%s] error: %s", model, resp.text[:300])
        resp.raise_for_status()
    choices = resp.json().get("choices")
    if not choices:
        raise ValueError(f"Groq returned no choices for {model}")
    reply = choices[0]["message"]["content"].strip()
    reply = reply.replace("```", "").replace("<br>", "\n").strip()
    logger.info("Groq [%s] reply (%d chars)", model, len(reply))
    return reply


def _call_openrouter(model: str, messages: list, key: str) -> str:
    """Call OpenRouter API. Raises on failure."""
    resp = requests.post(
        OPENROUTER_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type":  "application/json",
            "HTTP-Referer":  "https://plately.app",
            "X-Title":       "Plately",
        },
        json={"model": model, "messages": messages, "max_tokens": 600},
        timeout=20,
    )
    logger.info("OpenRouter [%s] status: %d", model, resp.status_code)
    if resp.status_code != 200:
        logger.error("OpenRouter [%s] error: %s", model, resp.text[:300])
        resp.raise_for_status()
    choices = resp.json().get("choices")
    if not choices:
        raise ValueError(f"OpenRouter returned no choices for {model}")
    reply = choices[0]["message"]["content"].strip()
    reply = reply.replace("```", "").replace("<br>", "\n").strip()
    logger.info("OpenRouter [%s] reply (%d chars)", model, len(reply))
    return reply


# ── Main AI caller ─────────────────────────────────────────────────────────────
def _ask_ai(message: str, history: list) -> tuple[str, bool]:
    """
    Returns (reply, is_fallback).
    Chain: Groq → OpenRouter → smart hardcoded reply.
    Never raises — always returns something useful.
    """
    if not history:
        cached = _get_cached(message)
        if cached:
            return cached, False

    msgs          = _build_messages(message, history)
    groq_key      = os.getenv("GROQ_API_KEY", "").strip()
    openrouter_key = os.getenv("OPENROUTER_API_KEY", "").strip()

    # ── 1. Try Groq first ─────────────────────────────────────────────────────
    if groq_key:
        for model in GROQ_MODELS:
            try:
                reply = _call_groq(model, msgs, groq_key)
                if not history:
                    _set_cached(message, reply)
                return reply, False
            except Exception as e:
                logger.warning("Groq [%s] failed: %s", model, e)
    else:
        logger.warning("GROQ_API_KEY not set — skipping Groq")

    # ── 2. Try OpenRouter ─────────────────────────────────────────────────────
    if openrouter_key:
        for model in OPENROUTER_MODELS:
            try:
                reply = _call_openrouter(model, msgs, openrouter_key)
                if not history:
                    _set_cached(message, reply)
                return reply, False
            except Exception as e:
                logger.warning("OpenRouter [%s] failed: %s", model, e)
    else:
        logger.warning("OPENROUTER_API_KEY not set — skipping OpenRouter")

    # ── 3. Smart hardcoded fallback ───────────────────────────────────────────
    logger.warning("All AI providers failed — returning smart fallback reply")
    return random.choice(_FALLBACK_REPLIES), True


# ── Rate limit key ─────────────────────────────────────────────────────────────
def _get_user_id() -> str:
    try:
        data = request.get_json(silent=True) or {}
        uid  = str(data.get("user_id", "")).strip()
        if uid and uid != "anonymous":
            return uid
    except Exception:
        pass
    return get_remote_address()


# ── Route ──────────────────────────────────────────────────────────────────────
@bp.route("/api/chat", methods=["POST"])
@limiter.limit("20 per minute", key_func=_get_user_id)
def chat():
    try:
        data    = request.json or {}
        message = (data.get("message") or "").strip()
        history = data.get("history") or []

        if not message:
            return jsonify({"status": "error", "message": "message required"}), 400

        if len(message) > MAX_MSG_LEN:
            message = message[:MAX_MSG_LEN]
        message = "".join(c for c in message if c >= " " or c in "\n\t")

        if not isinstance(history, list):
            history = []
        history = [h for h in history if isinstance(h, dict)
                   and "role" in h and "content" in h]

        reply, is_fallback = _ask_ai(message, history)

        return jsonify({
            "status": "ok",
            "data":   {"reply": reply},
            # Let Flutter know if this was a fallback so it can show a subtle indicator
            "fallback": is_fallback,
        }), 200

    except Exception as e:
        logger.exception("Unexpected chat error")
        return jsonify({
            "status":  "error",
            "message": "Something went wrong. Please try again.",
        }), 500
