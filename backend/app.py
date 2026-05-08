"""
Plately V2 — Flask Application Factory
Production-hardened: rate limiting, structured logging, security headers, proper config.

Dev:  python app.py
Prod: python wsgi.py
"""

import os
import logging
import logging.config
from flask import Flask, g, request
from flask_cors import CORS
from flask_compress import Compress
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv

load_dotenv(override=True)

# ── Logging ───────────────────────────────────────────────────────────────────
# Structured log format: timestamp | level | module | message
# Goes to stdout (captured by systemd/supervisor in prod)
logging.config.dictConfig({
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "standard": {
            "format": "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            "datefmt": "%Y-%m-%d %H:%M:%S",
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "standard",
            "stream": "ext://sys.stdout",
        }
    },
    "root": {"level": "INFO", "handlers": ["console"]},
    # Quiet noisy libs
    "loggers": {
        "werkzeug": {"level": "WARNING"},
        "waitress": {"level": "INFO"},
    },
})

logger = logging.getLogger(__name__)

# ── Environment config ─────────────────────────────────────────────────────────
ENV       = os.getenv("FLASK_ENV", "production")
IS_DEV    = ENV == "development"
PORT      = int(os.getenv("PORT", 5000))
SECRET    = os.getenv("SECRET_KEY", "")

if not IS_DEV and not SECRET:
    raise RuntimeError("SECRET_KEY must be set in production. Add it to .env")

# ── Rate limiter (shared across app) ──────────────────────────────────────────
# Storage: in-memory (fine for single-process). Upgrade to Redis for multi-worker.
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["200 per minute", "2000 per hour"],
    storage_uri="memory://",
)


def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = SECRET or "plately-dev-only-secret"

    # ── Gzip compression ──────────────────────────────────────────────────────
    # Compresses JSON API responses automatically. Min 500 bytes — no point
    # compressing tiny pings. Excludes image/* (already compressed).
    app.config["COMPRESS_MIMETYPES"] = [
        "application/json",
        "text/plain",
        "text/html",
    ]
    app.config["COMPRESS_LEVEL"] = 6        # balanced speed/size
    app.config["COMPRESS_MIN_SIZE"] = 500   # skip compressing tiny responses
    Compress(app)

    # ── CORS ──────────────────────────────────────────────────────────────────
    # Dev: open. Prod: lock to your actual domain.
    allowed_origins = os.getenv("ALLOWED_ORIGINS", "*" if IS_DEV else "")
    if not IS_DEV and not allowed_origins:
        logger.warning("ALLOWED_ORIGINS not set — CORS will block all cross-origin requests")
    CORS(app, resources={r"/api/*": {"origins": allowed_origins}})

    # ── Rate limiter init ─────────────────────────────────────────────────────
    limiter.init_app(app)

    # ── Blueprints ────────────────────────────────────────────────────────────
    from routes.scan      import bp as scan_bp
    from routes.recipes   import bp as recipes_bp
    from routes.chat      import bp as chat_bp
    from routes.goals     import bp as goals_bp
    from routes.favorites import bp as favorites_bp
    from routes.history   import bp as history_bp

    app.register_blueprint(scan_bp)
    app.register_blueprint(recipes_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(goals_bp)
    app.register_blueprint(favorites_bp)
    app.register_blueprint(history_bp)

    # ── Security headers (every response) ────────────────────────────────────
    @app.after_request
    def add_security_headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"]        = "DENY"
        response.headers["Referrer-Policy"]        = "no-referrer"
        # Don't cache API responses on clients
        if request.path.startswith("/api/"):
            response.headers["Cache-Control"] = "no-store"
        return response

    # ── Request logging ───────────────────────────────────────────────────────
    @app.before_request
    def _log_request():
        g._start = __import__("time").monotonic()

    @app.after_request
    def _log_response(response):
        duration_ms = round((__import__("time").monotonic() - g._start) * 1000)
        logger.info(
            "%s %s %s — %dms",
            request.method, request.path,
            response.status_code, duration_ms,
        )
        return response

    # ── Rate limit error handler ──────────────────────────────────────────────
    @app.errorhandler(429)
    def rate_limit_handler(e):
        return {"status": "error", "message": "Too many requests. Slow down."}, 429

    # ── Health check (no rate limit) ──────────────────────────────────────────
    @app.route("/api/health")
    @limiter.exempt
    def health():
        from database import query
        try:
            recipe_count = query("SELECT COUNT(*) as c FROM recipes")[0]["c"]
            return {
                "status": "ok",
                "service": "Plately API v2",
                "env": ENV,
                "recipes": recipe_count,
            }, 200
        except Exception as e:
            logger.error("Health check DB error: %s", e)
            return {"status": "degraded", "message": str(e)}, 500

    return app


# ── Dev entry point ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    from database import init_db
    init_db()
    app = create_app()
    logger.info("Starting Plately dev server on http://0.0.0.0:%d (debug=%s)", PORT, IS_DEV)
    app.run(host="0.0.0.0", port=PORT, debug=IS_DEV)
