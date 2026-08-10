"""Authentication edge-case tests for the Flask backend.

Covers Authorization header parsing, GitHub identity derivation, LDAP
manager enforcement, GitHub API error handling, and per-request identity
caching. These tests run against the same real PostgreSQL container used by
``test_server.py`` and mock external services (GitHub, LDAP) where appropriate.
"""

import json
import os
import tempfile
from unittest import mock

import psycopg2
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


@pytest.fixture
def db_conn():
    """Real PostgreSQL connection for direct DB assertions."""
    url = os.environ["DATABASE_URL"]
    conn = psycopg2.connect(url)
    try:
        yield conn
    finally:
        conn.close()


@pytest.fixture(autouse=True)
def clear_submissions(db_conn):
    """Wipe submissions before each test for isolated assertions."""
    with db_conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE submissions RESTART IDENTITY CASCADE")
        db_conn.commit()


# ── Authorization header parsing ─────────────────────────────────────────────


def test_missing_authorization_header_returns_401(client):
    resp = client.post("/api/submissions", json={"title": "x"})
    assert resp.status_code == 401
    assert resp.json == {"error": "Missing or invalid Authorization header"}


def test_non_bearer_authorization_header_returns_401(client):
    resp = client.post(
        "/api/submissions",
        json={"title": "x"},
        headers={"Authorization": "Basic dXNlcjpwYXNz"},
    )
    assert resp.status_code == 401
    assert resp.json == {"error": "Missing or invalid Authorization header"}


def test_empty_bearer_token_returns_401(client):
    resp = client.post(
        "/api/submissions",
        json={"title": "x"},
        headers={"Authorization": "Bearer   "},
    )
    assert resp.status_code == 401
    assert resp.json == {"error": "Missing or invalid Authorization header"}


# ── GitHub identity derivation ──────────────────────────────────────────────


def _patch_github(monkeypatch, user, emails):
    monkeypatch.setattr(server_module, "_github_user", lambda _token: user)
    monkeypatch.setattr(server_module, "_github_emails", lambda _token: emails)


def test_derive_identity_returns_expected_fields(monkeypatch):
    user = {"login": "rilsmith", "name": "Riley Smith", "avatar_url": "https://avatar"}
    emails = [{"email": "rilsmith@example.com", "primary": True, "verified": True}]
    _patch_github(monkeypatch, user, emails)

    identity = server_module._derive_identity("ghu_token")
    assert identity["login"] == "rilsmith"
    assert identity["name"] == "Riley Smith"
    assert identity["email"] == "rilsmith@example.com"
    assert identity["avatar_url"] == "https://avatar"
    assert identity["uid"] == "rilsmith"


def test_derive_identity_strips_email_tag_and_domain(monkeypatch):
    user = {"login": "rilsmith", "name": None, "avatar_url": ""}
    emails = [{"email": "rilsmith+tag@example.com", "primary": True, "verified": True}]
    _patch_github(monkeypatch, user, emails)

    identity = server_module._derive_identity("ghu_token")
    assert identity["email"] == "rilsmith+tag@example.com"
    assert identity["uid"] == "rilsmith"
    assert identity["name"] == "rilsmith"  # falls back to login


def test_derive_identity_falls_back_to_any_verified_email(monkeypatch):
    user = {"login": "rilsmith", "name": "Riley Smith", "avatar_url": ""}
    emails = [
        {"email": "rilsmith@example.com", "primary": False, "verified": True},
        {"email": "other@example.com", "primary": True, "verified": False},
    ]
    _patch_github(monkeypatch, user, emails)

    identity = server_module._derive_identity("ghu_token")
    assert identity["email"] == "rilsmith@example.com"
    assert identity["uid"] == "rilsmith"


def test_derive_identity_raises_when_no_verified_email(monkeypatch):
    monkeypatch.delenv("ALLOW_UNVERIFIED_TEST_EMAIL", raising=False)
    user = {"login": "rilsmith", "name": "Riley Smith", "avatar_url": ""}
    emails = [
        {"email": "rilsmith@example.com", "primary": True, "verified": False},
        {"email": "other@example.com", "primary": False, "verified": False},
    ]
    _patch_github(monkeypatch, user, emails)

    with pytest.raises(server_module.AuthError, match="No verified primary email"):
        server_module._derive_identity("ghu_token")


def test_derive_identity_raises_when_email_has_no_at_symbol(monkeypatch):
    user = {"login": "rilsmith", "name": "Riley Smith", "avatar_url": ""}
    emails = [{"email": "notanemail", "primary": True, "verified": True}]
    _patch_github(monkeypatch, user, emails)

    with pytest.raises(server_module.AuthError, match="Invalid primary email"):
        server_module._derive_identity("ghu_token")


def test_derive_identity_raises_when_uid_is_empty(monkeypatch):
    user = {"login": "user", "name": "User", "avatar_url": ""}
    emails = [{"email": "@example.com", "primary": True, "verified": True}]
    _patch_github(monkeypatch, user, emails)

    with pytest.raises(server_module.AuthError, match="Could not derive a user UID"):
        server_module._derive_identity("ghu_token")


def test_github_user_403_returns_401(client, monkeypatch):
    def _raise_forbidden(_token):
        raise server_module.AuthError("GitHub token rejected (403)")

    monkeypatch.setattr(server_module, "_github_user", _raise_forbidden)
    resp = client.post(
        "/api/submissions",
        json={"title": "x"},
        headers={"Authorization": "Bearer rate_limited_token"},
    )
    assert resp.status_code == 401
    assert "error" in resp.json


def test_github_user_500_returns_503(client, monkeypatch):
    def _raise_unavailable(_token):
        raise server_module.GitHubUnavailableError("GitHub API unavailable (500)")

    monkeypatch.setattr(server_module, "_github_user", _raise_unavailable)
    resp = client.post(
        "/api/submissions",
        json={"title": "x"},
        headers={"Authorization": "Bearer token"},
    )
    assert resp.status_code == 503
    assert "error" in resp.json


# ── LDAP manager enforcement ─────────────────────────────────────────────────


def test_get_manager_raises_when_user_not_found_in_ldap(monkeypatch):
    monkeypatch.setattr(server_module, "_ldap_lookup", lambda _uid: {"found": False})
    with pytest.raises(server_module.AuthError, match="User not found in LDAP"):
        server_module._get_manager("rilsmith")


def test_get_manager_raises_when_manager_missing(monkeypatch):
    monkeypatch.setattr(
        server_module,
        "_ldap_lookup",
        lambda _uid: {"found": True, "manager": "", "departmentNumber": ""},
    )
    with pytest.raises(server_module.AuthError, match="Manager information not available"):
        server_module._get_manager("rilsmith")


def test_ldap_lookup_parses_manager_dn(monkeypatch):
    """Manager attribute from LDAP is a full DN; only the cn value is returned."""
    # _ldap_lookup talks to the real LDAP server in the current implementation.
    # We monkeypatch the underlying Connection.search result to verify parsing.
    fake_entry = mock.MagicMock()
    fake_entry.entry_attributes_as_dict = {
        "cn": ["Riley Smith"],
        "displayName": ["Riley Smith"],
        "mail": ["rilsmith@example.com"],
        "manager": ["cn=jbellows,ou=people,ou=adbe"],
        "departmentNumber": ["12345"],
    }

    fake_conn = mock.MagicMock()
    fake_conn.entries = [fake_entry]
    fake_conn.search.return_value = None
    fake_conn.unbind.return_value = None

    fake_server = mock.MagicMock()

    with mock.patch.object(server_module, "Server", return_value=fake_server):
        with mock.patch.object(
            server_module, "Connection", return_value=fake_conn
        ) as conn_cls:
            conn_cls.side_effect = lambda *args, **kwargs: fake_conn
            result = server_module._ldap_lookup("rilsmith")

    assert result["found"] is True
    assert result["manager"] == "jbellows"
    assert result["departmentNumber"] == "12345"


# ── OAuth callback edge cases ───────────────────────────────────────────────


def test_auth_callback_redirects_with_error_from_github(client):
    resp = client.get("/auth?error=access_denied&error_description=user+denied")
    assert resp.status_code == 302
    location = resp.headers["Location"]
    assert location.startswith("/?error=")
    assert "access_denied" in location


# ── Per-request identity caching ─────────────────────────────────────────────


def test_identity_is_cached_within_request_but_not_between_requests(client, monkeypatch):
    """_get_identity should validate the token only once per request, but each
    request must re-validate the token (i.e. no server-level token cache)."""
    call_count = 0

    def _tracked_derive(token):
        nonlocal call_count
        call_count += 1
        return {
            "login": "rilsmith",
            "name": "Riley Smith",
            "email": "rilsmith@example.com",
            "avatar_url": "",
            "uid": "rilsmith",
        }

    monkeypatch.setattr(server_module, "_derive_identity", _tracked_derive)
    monkeypatch.setattr(
        server_module, "_get_manager", lambda _uid: {"manager_uid": "jbellows", "department_number": ""}
    )

    # One request calls _get_identity multiple times via _get_manager; it
    # should be memoized inside the Flask request context.
    with app.test_request_context(
        "/api/submissions/team", headers={"Authorization": "Bearer token"}
    ):
        server_module._get_identity()
        server_module._get_identity()
        server_module._get_identity()
        assert call_count == 1

    # A fresh request context should re-derive identity.
    with app.test_request_context(
        "/api/submissions/team", headers={"Authorization": "Bearer token"}
    ):
        server_module._get_identity()
        assert call_count == 2


# ── Runtime database connectivity failures ───────────────────────────────────


def test_create_submission_returns_500_when_db_fails(client, monkeypatch):
    monkeypatch.setattr(
        server_module,
        "_get_identity",
        lambda: {
            "login": "rilsmith",
            "name": "Riley Smith",
            "email": "rilsmith@example.com",
            "avatar_url": "",
            "uid": "rilsmith",
        },
    )
    monkeypatch.setattr(
        server_module, "_get_manager", lambda _uid: {"manager_uid": "jbellows", "department_number": ""}
    )
    monkeypatch.setattr(
        server_module,
        "_get_db_conn",
        lambda: (_ for _ in ()).throw(Exception("connection refused")),
    )

    resp = client.post(
        "/api/submissions",
        json={
            "dimensions": [
                {"id": 1, "name": "D1", "score": 1.0, "color": "#000"}
            ],
            "applicationDomains": [
                {
                    "id": 1,
                    "name": "Domain A",
                    "shortName": "A",
                    "applicability": "in_scope",
                    "involvement": "none",
                    "value": "low",
                    "confidence": "low",
                    "capabilityIds": [],
                }
            ],
        },
        headers={"Authorization": "Bearer token"},
    )
    assert resp.status_code == 500
    assert resp.json == {"error": "Internal server error"}
