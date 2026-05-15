"""
SecurePipe Sample Flask Application
Used as the target for the DevSecOps pipeline scanning.
"""

import os
from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import logging

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ─── Security headers ────────────────────────────────────────────────────────
@app.after_request
def add_security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


# ─── DB connection (optional — gracefully skipped if no DB) ──────────────────
def get_db():
    db_host = os.environ.get("DB_HOST")
    if not db_host:
        return None
    try:
        conn = psycopg2.connect(
            host=db_host,
            user=os.environ.get("DB_USER", "app"),
            password=os.environ.get("DB_PASSWORD", ""),
            dbname=os.environ.get("DB_NAME", "securepipe"),
            connect_timeout=3,
        )
        return conn
    except Exception as e:
        logger.warning(f"DB connection failed: {e}")
        return None


# ─── Routes ──────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return jsonify({
        "service": "SecurePipe",
        "version": "2.0.0",
        "status": "running",
        "pipeline": [
            "Trufflehog → Secrets Detection",
            "SonarQube  → SAST",
            "Trivy      → Container Scan",
            "Checkov    → IaC Scan",
            "OWASP ZAP  → DAST",
        ]
    })


@app.route("/health")
def health():
    """Health endpoint — used by Docker HEALTHCHECK and OWASP ZAP target."""
    db = get_db()
    db_status = "connected" if db else "unavailable"
    if db:
        db.close()

    return jsonify({
        "status": "healthy",
        "db": db_status
    }), 200


@app.route("/api/items", methods=["GET"])
def get_items():
    """Sample GET endpoint."""
    items = [
        {"id": 1, "name": "Pipeline Stage 1", "tool": "Trufflehog"},
        {"id": 2, "name": "Pipeline Stage 2", "tool": "SonarQube"},
        {"id": 3, "name": "Pipeline Stage 3", "tool": "Trivy"},
        {"id": 4, "name": "Pipeline Stage 4", "tool": "Checkov"},
        {"id": 5, "name": "Pipeline Stage 5", "tool": "OWASP ZAP"},
    ]
    return jsonify({"items": items, "count": len(items)})


@app.route("/api/items", methods=["POST"])
def create_item():
    """Sample POST endpoint."""
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "name field is required"}), 400

    # Sanitise input — never use raw user input in queries
    name = str(data["name"])[:100].strip()
    return jsonify({"id": 999, "name": name, "created": True}), 201


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # Never run debug=True in production
    app.run(host="0.0.0.0", port=port, debug=False)
