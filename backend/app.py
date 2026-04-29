"""
Plately V2 — Flask Backend
Run: python app.py
Requires .env with OPENROUTER_API_KEY and GOOGLE_VISION_API_KEY
"""

import os
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from database import init_db
from routes.scan      import bp as scan_bp
from routes.recipes   import bp as recipes_bp
from routes.chat      import bp as chat_bp
from routes.goals     import bp as goals_bp
from routes.favorites import bp as favorites_bp
from routes.history   import bp as history_bp


def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = os.getenv('SECRET_KEY', 'plately-dev-secret')

    # Allow all origins in dev — restrict to app domain in production
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # Register route blueprints
    app.register_blueprint(scan_bp)
    app.register_blueprint(recipes_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(goals_bp)
    app.register_blueprint(favorites_bp)
    app.register_blueprint(history_bp)

    # Health check
    @app.route('/api/health')
    def health():
        return {"status": "ok", "service": "Plately API v2"}, 200

    return app


if __name__ == '__main__':
    init_db()
    app = create_app()
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV', 'development') == 'development'
    print(f"[Plately] Running on http://localhost:{port}  (debug={debug})")
    app.run(host='0.0.0.0', port=port, debug=debug)
