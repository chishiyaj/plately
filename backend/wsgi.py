"""
wsgi.py — Entry point for both gunicorn (Render/prod) and waitress (Windows local).

Render:   gunicorn wsgi:application (set in Procfile)
Local:    python wsgi.py
"""
import os
from dotenv import load_dotenv
load_dotenv(override=True)

from database import init_db
from app import create_app

init_db()
application = app = create_app()  # gunicorn needs 'application' OR 'app'

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    env  = os.getenv("FLASK_ENV", "production")

    if os.name == "nt":  # Windows — use waitress
        from waitress import serve
        import logging
        logging.getLogger(__name__).info("Waitress on port %d", port)
        serve(application, host="0.0.0.0", port=port, threads=8)
    else:  # Linux — use gunicorn directly
        import subprocess, sys
        subprocess.run([
            sys.executable, "-m", "gunicorn",
            "wsgi:application",
            "--workers", "2",
            "--threads", "4",
            "--bind", f"0.0.0.0:{port}",
            "--timeout", "120",
        ])
