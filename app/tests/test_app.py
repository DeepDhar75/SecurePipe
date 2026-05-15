"""
Tests for SecurePipe Flask application.
SonarQube will use coverage reports from these tests.
"""

import pytest
import json
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


# ─── Index ───────────────────────────────────────────────────────────────────
def test_index_returns_200(client):
    res = client.get("/")
    assert res.status_code == 200


def test_index_returns_service_name(client):
    res = client.get("/")
    data = json.loads(res.data)
    assert data["service"] == "SecurePipe"


# ─── Health ──────────────────────────────────────────────────────────────────
def test_health_returns_200(client):
    res = client.get("/health")
    assert res.status_code == 200


def test_health_returns_healthy_status(client):
    res = client.get("/health")
    data = json.loads(res.data)
    assert data["status"] == "healthy"


# ─── Items GET ───────────────────────────────────────────────────────────────
def test_get_items_returns_200(client):
    res = client.get("/api/items")
    assert res.status_code == 200


def test_get_items_returns_list(client):
    res = client.get("/api/items")
    data = json.loads(res.data)
    assert "items" in data
    assert isinstance(data["items"], list)
    assert data["count"] == len(data["items"])


# ─── Items POST ──────────────────────────────────────────────────────────────
def test_create_item_success(client):
    res = client.post(
        "/api/items",
        data=json.dumps({"name": "Test Item"}),
        content_type="application/json"
    )
    assert res.status_code == 201
    data = json.loads(res.data)
    assert data["created"] is True


def test_create_item_missing_name_returns_400(client):
    res = client.post(
        "/api/items",
        data=json.dumps({}),
        content_type="application/json"
    )
    assert res.status_code == 400


def test_create_item_no_body_returns_400(client):
    res = client.post("/api/items", content_type="application/json")
    assert res.status_code == 400


# ─── Security Headers ────────────────────────────────────────────────────────
def test_security_headers_present(client):
    res = client.get("/health")
    assert res.headers.get("X-Content-Type-Options") == "nosniff"
    assert res.headers.get("X-Frame-Options") == "DENY"
    assert res.headers.get("X-XSS-Protection") == "1; mode=block"
    assert "Content-Security-Policy" in res.headers
