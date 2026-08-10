"""Backend tests for the Flask refactor.

Tests run against a real PostgreSQL container (see docker-compose.yml) and mock
external services (GitHub, LDAP) where appropriate.
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
    "DATABASE_URL", "postgres://postgres:postgres@localhost:5432/capability_dashboard"
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


def _auth_identity(uid="rilsmith", name="Riley Smith"):
    return {
        "login": uid,
        "name": name,
        "email": f"{uid}@example.com",
        "avatar_url": "",
        "uid": uid,
    }


def _auth_manager(manager_uid="jbellows", department_number="12345"):
    return {"manager_uid": manager_uid, "department_number": department_number}


def _set_identity(monkeypatch, uid="rilsmith", name="Riley Smith"):
    identity = _auth_identity(uid=uid, name=name)
    monkeypatch.setattr(server_module, "_get_identity", lambda: identity)


def _set_manager(monkeypatch, manager_uid="jbellows", department_number="12345"):
    manager = _auth_manager(manager_uid=manager_uid, department_number=department_number)
    monkeypatch.setattr(server_module, "_get_manager", lambda _uid: manager)


def _set_auth(monkeypatch, uid="rilsmith", name="Riley Smith", manager_uid="jbellows"):
    _set_identity(monkeypatch, uid=uid, name=name)
    _set_manager(monkeypatch, manager_uid=manager_uid)


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


# ── Submissions API ───────────────────────────────────────────────────────────


def _sample_payload(**overrides):
    payload = {
        "title": "Test Dashboard",
        "dimensions": [
            {"id": 1, "name": "Prompt Engineering", "score": 3.0, "color": "#2563EB"},
            {"id": 2, "name": "Context Engineering", "score": 4.0, "color": "#0D9488"},
        ],
        "applicationDomains": [
            {
                "id": 1,
                "name": "Discovery & Research",
                "shortName": "Discovery",
                "applicability": "in_scope",
                "involvement": "regular",
                "value": "high",
                "confidence": "moderate",
                "capabilityIds": [1],
            },
            {
                "id": 2,
                "name": "Requirements & Planning",
                "shortName": "Requirements",
                "applicability": "in_scope",
                "involvement": "none",
                "value": "low",
                "confidence": "low",
                "capabilityIds": [],
            },
        ],
        "maturityScale": [],
        "howToRead": "",
        "applicationHowToRead": "",
        "applicationMatrixHowToRead": "",
        "tiers": {"high": {"label": "", "color": "", "min": 4.0}, "medium": {"label": "", "color": "", "min": 2.5}, "low": {"label": "", "color": "", "min": 1.0}},
        "maxScore": 5,
    }
    payload.update(overrides)
    return payload


def _insert_submission(db_conn, uid, manager_uid, payload, submitted_at):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO submissions
                (user_uid, manager_uid, submitted_at, payload)
            VALUES (%s, %s, %s, %s)
            """,
            (uid, manager_uid, submitted_at, json.dumps(payload)),
        )
        db_conn.commit()


def test_post_submission_returns_201(client, monkeypatch):
    _set_auth(monkeypatch)
    payload = _sample_payload()
    resp = client.post(
        "/api/submissions",
        json=payload,
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 201
    data = resp.json
    assert "id" in data
    assert "submitted_at" in data
    assert len(data["id"]) > 0


def test_post_submission_stores_all_fields(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="rilsmith", name="Riley Smith", manager_uid="jbellows")
    payload = _sample_payload()
    client.post(
        "/api/submissions",
        json=payload,
        headers={"Authorization": "Bearer valid_token"},
    )
    with db_conn.cursor() as cur:
        cur.execute(
            "SELECT user_uid, user_email, user_display_name, manager_uid, department_number, payload FROM submissions WHERE user_uid = 'rilsmith'"
        )
        row = cur.fetchone()
    assert row[0] == "rilsmith"
    assert row[1] == "rilsmith@example.com"
    assert row[2] == "Riley Smith"
    assert row[3] == "jbellows"
    assert row[4] == "12345"
    stored = row[5]
    if isinstance(stored, str):
        stored = json.loads(stored)
    assert stored["title"] == "Test Dashboard"


def test_post_submission_rejects_unauthorized(client):
    resp = client.post("/api/submissions", json={"title": "x"})
    assert resp.status_code == 401
    assert "error" in resp.json


def test_post_submission_rejects_invalid_token(client, monkeypatch):
    monkeypatch.setattr(
        server_module,
        "_github_user",
        lambda _token: (_ for _ in ()).throw(server_module.AuthError("bad token")),
    )
    resp = client.post(
        "/api/submissions",
        json={"title": "x"},
        headers={"Authorization": "Bearer bad_token"},
    )
    assert resp.status_code == 401


def test_post_submission_rejects_empty_payload(client, monkeypatch):
    _set_auth(monkeypatch)
    resp = client.post(
        "/api/submissions",
        json={},
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 400
    assert "error" in resp.json


def test_post_submission_rejects_malformed_json(client, monkeypatch):
    _set_auth(monkeypatch)
    resp = client.post(
        "/api/submissions",
        data="not json",
        content_type="application/json",
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 400


def test_post_submission_rejects_non_json_content_type(client, monkeypatch):
    _set_auth(monkeypatch)
    resp = client.post(
        "/api/submissions",
        data="title=x",
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 400


def test_get_submissions_me_requires_auth(client):
    resp = client.get("/api/submissions/me")
    assert resp.status_code == 401


def test_get_submissions_me_returns_latest(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1")
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(dimensions=[{"id": 1, "name": "D1", "score": 1.0, "color": "#000"}]),
        "2024-01-01T00:00:00+00:00",
    )
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(dimensions=[{"id": 1, "name": "D1", "score": 5.0, "color": "#000"}]),
        "2024-01-02T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/me", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 200
    assert resp.json["payload"]["dimensions"][0]["score"] == 5.0


def test_get_submissions_me_returns_404_when_empty(client, monkeypatch):
    _set_auth(monkeypatch, uid="newuser")
    resp = client.get(
        "/api/submissions/me", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 404
    assert "error" in resp.json


def test_get_submissions_me_excludes_other_users(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1")
    _insert_submission(
        db_conn,
        "user2",
        "jbellows",
        _sample_payload(),
        "2024-01-01T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/me", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 404


def test_get_submissions_team_requires_auth(client):
    resp = client.get("/api/submissions/team")
    assert resp.status_code == 401


def test_get_submissions_team_returns_latest_per_user(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1")
    # user1 latest
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(dimensions=[{"id": 1, "name": "D1", "score": 5.0, "color": "#000"}]),
        "2024-01-02T00:00:00+00:00",
    )
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(dimensions=[{"id": 1, "name": "D1", "score": 1.0, "color": "#000"}]),
        "2024-01-01T00:00:00+00:00",
    )
    # user2 latest
    _insert_submission(
        db_conn,
        "user2",
        "jbellows",
        _sample_payload(dimensions=[{"id": 1, "name": "D1", "score": 3.0, "color": "#000"}]),
        "2024-01-01T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/team", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 200
    submissions = resp.json["submissions"]
    assert len(submissions) == 2
    by_user = {s["user_uid"]: s["payload"]["dimensions"][0]["score"] for s in submissions}
    assert by_user["user1"] == 5.0
    assert by_user["user2"] == 3.0


def test_get_submissions_team_excludes_other_managers(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1", manager_uid="jbellows")
    _insert_submission(
        db_conn,
        "otheruser",
        "othermanager",
        _sample_payload(),
        "2024-01-01T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/team", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 200
    assert resp.json["submissions"] == []


def test_get_submissions_team_returns_empty_list_when_no_team(client, monkeypatch):
    _set_auth(monkeypatch, uid="lonelyuser")
    resp = client.get(
        "/api/submissions/team", headers={"Authorization": "Bearer valid_token"}
    )
    assert resp.status_code == 200
    assert resp.json["submissions"] == []


def test_get_submissions_team_aggregate_requires_auth(client):
    resp = client.get("/api/submissions/team/aggregate")
    assert resp.status_code == 401


def test_get_submissions_team_aggregate_returns_averages(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1")
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(
            dimensions=[
                {"id": 1, "name": "D1", "score": 2.0, "color": "#000"},
                {"id": 2, "name": "D2", "score": 4.0, "color": "#fff"},
            ],
            applicationDomains=[
                {
                    "id": 1,
                    "name": "Domain A",
                    "shortName": "A",
                    "applicability": "in_scope",
                    "involvement": "regular",
                    "value": "high",
                    "confidence": "high",
                    "capabilityIds": [],
                },
            ],
        ),
        "2024-01-01T00:00:00+00:00",
    )
    _insert_submission(
        db_conn,
        "user2",
        "jbellows",
        _sample_payload(
            dimensions=[
                {"id": 1, "name": "D1", "score": 4.0, "color": "#000"},
                {"id": 2, "name": "D2", "score": 6.0, "color": "#fff"},
            ],
            applicationDomains=[
                {
                    "id": 1,
                    "name": "Domain A",
                    "shortName": "A",
                    "applicability": "in_scope",
                    "involvement": "occasional",
                    "value": "moderate",
                    "confidence": "low",
                    "capabilityIds": [],
                },
            ],
        ),
        "2024-01-01T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/team/aggregate",
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 200
    data = resp.json
    assert data["member_count"] == 2
    dims = {d["id"]: d for d in data["dimensions"]}
    assert dims[1]["average"] == 3.0
    assert dims[2]["average"] == 5.0
    domains = {d["id"]: d for d in data["domains"]}
    assert domains[1]["involvement_average"] == 1.5
    assert domains[1]["value_average"] == 1.5
    assert domains[1]["confidence_average"] == 1.0


def test_get_submissions_team_aggregate_uses_latest_per_user(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1")
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(
            dimensions=[{"id": 1, "name": "D1", "score": 1.0, "color": "#000"}]
        ),
        "2024-01-01T00:00:00+00:00",
    )
    _insert_submission(
        db_conn,
        "user1",
        "jbellows",
        _sample_payload(
            dimensions=[{"id": 1, "name": "D1", "score": 5.0, "color": "#000"}]
        ),
        "2024-01-02T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/team/aggregate",
        headers={"Authorization": "Bearer valid_token"},
    )
    dims = {d["id"]: d for d in resp.json["dimensions"]}
    assert dims[1]["average"] == 5.0


def test_get_submissions_team_aggregate_excludes_other_managers(client, monkeypatch, db_conn):
    _set_auth(monkeypatch, uid="user1", manager_uid="jbellows")
    _insert_submission(
        db_conn,
        "otheruser",
        "othermanager",
        _sample_payload(
            dimensions=[{"id": 1, "name": "D1", "score": 9.0, "color": "#000"}]
        ),
        "2024-01-01T00:00:00+00:00",
    )
    resp = client.get(
        "/api/submissions/team/aggregate",
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.json["member_count"] == 0
    assert resp.json["dimensions"] == []
    assert resp.json["domains"] == []


def test_get_submissions_team_aggregate_returns_empty_when_no_submissions(client, monkeypatch):
    _set_auth(monkeypatch, uid="newuser")
    resp = client.get(
        "/api/submissions/team/aggregate",
        headers={"Authorization": "Bearer valid_token"},
    )
    assert resp.status_code == 200
    assert resp.json["member_count"] == 0
    assert resp.json["dimensions"] == []
    assert resp.json["domains"] == []


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
