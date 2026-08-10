"""Backend tests for the Flask refactor.

Tests run against a real PostgreSQL container (see docker-compose.yml) and mock
external services (GitHub, LDAP) where appropriate.
"""

import json
import os
import tempfile
from unittest import mock

import pytest

# Set required environment variables before importing the server module.
os.environ["GITHUB_CLIENT_ID"] = "test_client_id"
os.environ["GITHUB_CLIENT_SECRET"] = "test_client_secret"
os.environ.setdefault(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/capability_dashboard"
)
os.environ["REDIRECT_URI"] = "http://localhost:5000/auth"
os.environ["LDAP_URL"] = "ldap://ldap.loc.adobe.net"
os.environ["LDAP_BASE_DN"] = "o=adbe"
os.environ["CORS_ORIGIN"] = "http://localhost:5000"

# Use a temporary web root so server.py can import without a real Flutter build.
_tmp_web = tempfile.TemporaryDirectory()
os.environ["WEB_DIR"] = _tmp_web.name
with open(os.path.join(_tmp_web.name, "index.html"), "w", encoding="utf-8") as f:
    f.write("<html><body>AI Capability Dashboard</body></html><!-- flutter -->")
with open(os.path.join(_tmp_web.name, "manifest.json"), "w", encoding="utf-8") as f:
    f.write('{"name":"AI Capability Dashboard"}')

import server as server_module  # noqa: E402
from server import app  # noqa: E402


@pytest.fixture
def client():
    """Flask test client fixture."""
    return app.test_client()


# ── Health ───────────────────────────────────────────────────────────────────


def test_health_returns_200(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json == {"status": "ok"}


def test_health_requires_no_auth(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert "error" not in resp.json


# ── Readiness ─────────────────────────────────────────────────────────────────


def test_ready_returns_200_when_db_reachable(client):
    resp = client.get("/ready")
    assert resp.status_code == 200
    assert resp.json == {"status": "ok"}


def test_ready_returns_503_when_db_unreachable(client, monkeypatch):
    monkeypatch.setattr(server_module, "DATABASE_URL", "postgresql://invalid:5432/db")
    resp = client.get("/ready")
    assert resp.status_code == 503
    assert "error" in resp.json
    assert "Database unreachable" in resp.json["error"]


# ── GitHub OAuth callback ─────────────────────────────────────────────────────


def test_auth_redirects_with_error_when_code_missing(client):
    resp = client.get("/auth")
    assert resp.status_code == 302
    assert "error=missing_code" in resp.headers["Location"]


def test_auth_redirects_with_error_on_github_failure(client):
    with mock.patch.object(server_module, "_exchange_code", side_effect=Exception("bad code")):
        resp = client.get("/auth?code=invalid&state=abc")
    assert resp.status_code == 302
    assert "error=bad%20code" in resp.headers["Location"]


def test_auth_redirects_with_token_on_success(client):
    with mock.patch.object(server_module, "_exchange_code", return_value="ghu_test_token"):
        resp = client.get("/auth?code=valid&state=abc")
    assert resp.status_code == 302
    location = resp.headers["Location"]
    assert "token=ghu_test_token" in location
    assert "state=abc" in location


# ── LDAP proxy ─────────────────────────────────────────────────────────────────


def test_ldap_returns_400_when_uid_missing(client):
    resp = client.get("/api/ldap")
    assert resp.status_code == 400
    assert resp.json == {"error": "uid parameter required"}


def test_ldap_returns_manager_and_department_for_known_uid(client):
    expected = {
        "found": True,
        "uid": "rilsmith",
        "displayName": "Riley Smith",
        "mail": "rilsmith@example.com",
        "manager": "jbellows",
        "departmentNumber": "12345",
    }
    with mock.patch.object(server_module, "_ldap_lookup", return_value=expected):
        resp = client.get("/api/ldap?uid=rilsmith")
    assert resp.status_code == 200
    assert resp.json == expected


def test_ldap_returns_found_false_for_unknown_uid(client):
    expected = {"found": False, "uid": "nobody"}
    with mock.patch.object(server_module, "_ldap_lookup", return_value=expected):
        resp = client.get("/api/ldap?uid=nobody")
    assert resp.status_code == 200
    assert resp.json == expected


def test_ldap_returns_500_when_ldap_unreachable(client):
    with mock.patch.object(
        server_module, "_ldap_lookup", side_effect=Exception("LDAP connection failed")
    ):
        resp = client.get("/api/ldap?uid=rilsmith")
    assert resp.status_code == 500
    assert "error" in resp.json


# ── CORS / general API behavior ──────────────────────────────────────────────


def test_cors_headers_set_to_configured_origin(client):
    resp = client.get("/health", headers={"Origin": "http://localhost:5000"})
    assert resp.headers["Access-Control-Allow-Origin"] == "http://localhost:5000"


def test_preflight_options_returns_204(client):
    resp = client.options(
        "/api/submissions",
        headers={
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Authorization, Content-Type",
            "Origin": "http://localhost:5000",
        },
    )
    assert resp.status_code == 204
    assert resp.headers["Access-Control-Allow-Origin"] == "http://localhost:5000"


def test_unknown_api_path_returns_404_json(client):
    resp = client.get("/api/unknown")
    assert resp.status_code == 404
    assert resp.json == {"error": "Not found"}


# ── Static files (local development) ─────────────────────────────────────────


def test_root_serves_index_html(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"flutter" in resp.data.lower() or b"AI Capability" in resp.data


def test_static_asset_served(client):
    resp = client.get("/manifest.json")
    assert resp.status_code == 200
    assert resp.content_type == "application/json"


def test_unknown_path_falls_back_to_index_html(client):
    resp = client.get("/some/spa/route")
    assert resp.status_code == 200
    assert b"flutter" in resp.data.lower()
