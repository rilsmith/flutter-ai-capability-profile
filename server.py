#!/usr/bin/env python3
"""Flutter web SPA backend using Flask.

Serves the Flutter web build for local development and exposes API routes
for GitHub OAuth, LDAP proxy, health/readiness, and (in later milestones)
submission persistence.

All configuration and secrets are read from environment variables.
"""

import json
import logging
import os
import sys
import urllib.parse
import urllib.request
from typing import Any

import init_db
import psycopg2
from dotenv import load_dotenv
from flask import Flask, g, jsonify, redirect, request, send_from_directory
from ldap3 import ANONYMOUS, SUBTREE, Connection, Server
from urllib.error import HTTPError

# Load environment variables from an uncommitted .env file if present.
# Existing environment variables take precedence, so test fixtures are safe.
load_dotenv()


# ── Configuration ────────────────────────────────────────────────────────────

REQUIRED_ENV = [
    "GITHUB_CLIENT_ID",
    "GITHUB_CLIENT_SECRET",
    "DATABASE_URL",
    "REDIRECT_URI",
    "LDAP_URL",
    "LDAP_BASE_DN",
    "CORS_ORIGIN",
]

GITHUB_CLIENT_ID = os.environ.get("GITHUB_CLIENT_ID")
GITHUB_CLIENT_SECRET = os.environ.get("GITHUB_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("REDIRECT_URI")
LDAP_URL = os.environ.get("LDAP_URL")
LDAP_BASE_DN = os.environ.get("LDAP_BASE_DN")
DATABASE_URL = os.environ.get("DATABASE_URL")
CORS_ORIGIN = os.environ.get("CORS_ORIGIN")
WEB_DIR = os.environ.get("WEB_DIR", "build/web")
SERVE_STATIC = os.environ.get("SERVE_STATIC", "true").lower() in (
    "true",
    "1",
    "yes",
    "on",
)


def _validate_env() -> list[str]:
    """Return the list of required environment variables that are missing."""
    return [name for name in REQUIRED_ENV if not os.environ.get(name)]


_missing = _validate_env()
if _missing:
    print(f"ERROR: Missing required environment variables: {', '.join(_missing)}")
    print("Copy .env.example to .env and fill in the required values.")
    sys.exit(1)

if SERVE_STATIC:
    WEB_DIR_ABS = os.path.abspath(WEB_DIR)
    if not os.path.isdir(WEB_DIR_ABS):
        print(f"ERROR: Flutter web build not found at {WEB_DIR_ABS}")
        print("Run:  flutter build web")
        sys.exit(1)
else:
    WEB_DIR_ABS = ""


# ── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


# ── Flask app ────────────────────────────────────────────────────────────────

app = Flask(__name__)
app.config["PROPAGATE_EXCEPTIONS"] = True


# ── CORS helpers ─────────────────────────────────────────────────────────────

@app.after_request
def _add_cors_headers(response: Any) -> Any:
    """Attach CORS headers to every response."""
    response.headers["Access-Control-Allow-Origin"] = CORS_ORIGIN
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
    return response


# ── Custom errors ────────────────────────────────────────────────────────────

class AuthError(Exception):
    """Raised when a request cannot be authenticated."""


class ValidationError(Exception):
    """Raised when a request is malformed or missing required fields."""


class NotFoundError(Exception):
    """Raised when a requested resource does not exist."""


class GitHubUnavailableError(Exception):
    """Raised when the GitHub API is rate-limited or otherwise unavailable."""


# ── Error handling ────────────────────────────────────────────────────────────

@app.errorhandler(AuthError)
def _handle_auth_error(error: AuthError) -> Any:
    return jsonify({"error": str(error)}), 401


@app.errorhandler(ValidationError)
def _handle_validation_error(error: ValidationError) -> Any:
    return jsonify({"error": str(error)}), 400


@app.errorhandler(NotFoundError)
def _handle_not_found_error(error: NotFoundError) -> Any:
    return jsonify({"error": str(error)}), 404


@app.errorhandler(GitHubUnavailableError)
def _handle_github_unavailable_error(error: GitHubUnavailableError) -> Any:
    return jsonify({"error": str(error)}), 503


@app.errorhandler(404)
def _handle_not_found(_error: Any) -> Any:
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(Exception)
def _handle_exception(error: Any) -> Any:
    logger.exception("Unhandled error")
    return jsonify({"error": "Internal server error"}), 500


# ── Health / readiness ───────────────────────────────────────────────────────

def _db_check() -> None:
    """Raise if the database is unreachable."""
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    finally:
        conn.close()


@app.route("/health", methods=["GET"])
def health() -> Any:
    """Liveness probe: always returns 200."""
    return jsonify({"status": "ok"})


@app.route("/ready", methods=["GET"])
def ready() -> Any:
    """Readiness probe: depends on database connectivity."""
    try:
        _db_check()
        return jsonify({"status": "ok"})
    except Exception as exc:
        logger.exception("Database readiness check failed")
        return jsonify({"error": f"Database unreachable: {exc}"}), 503


# ── GitHub token validation ──────────────────────────────────────────────────


def _github_api_request(url: str, token: str) -> Any:
    """Call a GitHub API endpoint with a Bearer token."""
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "User-Agent": "ai-capability-dashboard",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)
    except HTTPError as exc:
        if exc.code in (401, 403):
            raise AuthError(f"GitHub token rejected ({exc.code})")
        if exc.code >= 500:
            raise GitHubUnavailableError(f"GitHub API unavailable ({exc.code})")
        raise GitHubUnavailableError(f"GitHub API error ({exc.code})")


def _github_user(token: str) -> dict:
    """Return the GitHub /user payload for a token."""
    data = _github_api_request("https://api.github.com/user", token)
    if not isinstance(data, dict):
        raise AuthError("Invalid response from GitHub /user")
    return data


def _github_emails(token: str) -> list:
    """Return the GitHub /user/emails payload for a token."""
    data = _github_api_request("https://api.github.com/user/emails", token)
    if not isinstance(data, list):
        raise AuthError("Invalid response from GitHub /user/emails")
    return data


def _derive_identity(token: str) -> dict:
    """Validate a GitHub token and derive the user identity and UID."""
    user = _github_user(token)
    emails = _github_emails(token)
    primary = next(
        (e for e in emails if e.get("primary") and e.get("verified")), None
    )
    if primary is None:
        primary = next((e for e in emails if e.get("verified")), None)
    if primary is None and os.environ.get("ALLOW_UNVERIFIED_TEST_EMAIL", "") == "true":
        # Local-dev-only escape hatch: accept an unverified primary email for
        # testing with tokens that do not have a verified email on file.
        primary = next((e for e in emails if e.get("primary")), None)
    if primary is None:
        raise AuthError("No verified primary email found for this GitHub account")

    email = primary.get("email", "")
    if "@" not in email:
        raise AuthError("Invalid primary email from GitHub")
    uid = email.split("@")[0].split("+")[0]
    if not uid:
        raise AuthError("Could not derive a user UID from the GitHub email")

    name = user.get("name") or user.get("login") or uid
    return {
        "token": token,
        "login": user.get("login"),
        "name": name,
        "email": email,
        "avatar_url": user.get("avatar_url"),
        "uid": uid,
    }


def _extract_bearer_token() -> str:
    """Read and validate the Authorization: Bearer header."""
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise AuthError("Missing or invalid Authorization header")
    token = header[7:].strip()
    if not token:
        raise AuthError("Missing or invalid Authorization header")
    return token


def _get_identity() -> dict:
    """Return the authenticated GitHub identity, validating once per request."""
    if "identity" in g:
        return g.identity
    token = _extract_bearer_token()
    g.identity = _derive_identity(token)
    return g.identity


def _get_manager(uid: str) -> dict:
    """Return manager_uid and department_number for a user UID from LDAP."""
    ldap = _ldap_lookup(uid)
    if not ldap.get("found"):
        raise AuthError("User not found in LDAP")
    manager_uid = ldap.get("manager", "")
    if not manager_uid:
        raise AuthError("Manager information not available from LDAP")
    return {
        "manager_uid": manager_uid,
        "department_number": ldap.get("departmentNumber", "") or "",
    }


# ── GitHub OAuth callback ────────────────────────────────────────────────────

def _exchange_code(code: str, state: str) -> str:
    """Exchange a GitHub authorization code for an access token."""
    body = urllib.parse.urlencode({
        "client_id": GITHUB_CLIENT_ID,
        "client_secret": GITHUB_CLIENT_SECRET,
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "state": state,
    }).encode()
    req = urllib.request.Request(
        "https://github.com/login/oauth/access_token",
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)
    if "error" in data:
        raise Exception(data.get("error_description", data["error"]))
    return data["access_token"]


@app.route("/auth", methods=["GET"])
def auth_callback() -> Any:
    """GitHub OAuth callback: exchange code and redirect to app with token."""
    code = request.args.get("code")
    state = request.args.get("state", "")

    if not code:
        error = request.args.get("error", "missing_code")
        return redirect(f"/?error={urllib.parse.quote(error)}")

    try:
        token = _exchange_code(code, state)
        return redirect(
            f"/?token={urllib.parse.quote(token)}&state={urllib.parse.quote(state)}"
        )
    except Exception as exc:
        logger.exception("GitHub code exchange failed")
        return redirect(f"/?error={urllib.parse.quote(str(exc))}")


# ── LDAP proxy ───────────────────────────────────────────────────────────────

def _ldap_lookup(uid: str) -> dict:
    """Look up a user in the configured LDAP directory."""
    server = Server(LDAP_URL)
    conn = Connection(server, authentication=ANONYMOUS, auto_bind=True)
    try:
        conn.search(
            LDAP_BASE_DN,
            f"(uid={uid})",
            search_scope=SUBTREE,
            attributes=["cn", "displayName", "mail", "manager", "departmentNumber"],
        )
        if not conn.entries:
            return {"found": False, "uid": uid}

        attrs = conn.entries[0].entry_attributes_as_dict
        raw_manager = (attrs.get("manager") or [""])[0]
        # Strip "cn=jbellows,ou=..." -> "jbellows"
        manager = ""
        if raw_manager:
            manager = raw_manager.split(",")[0].split("=")[-1]

        return {
            "found": True,
            "uid": uid,
            "displayName": (attrs.get("displayName") or [""])[0],
            "mail": (attrs.get("mail") or [""])[0],
            "manager": manager,
            "departmentNumber": (attrs.get("departmentNumber") or [""])[0],
        }
    finally:
        conn.unbind()


@app.route("/api/ldap", methods=["GET", "OPTIONS"])
def ldap_api() -> Any:
    """Public LDAP lookup proxy used by the Flutter app before login completes."""
    if request.method == "OPTIONS":
        return "", 204

    uid = request.args.get("uid", "").strip()
    if not uid:
        return jsonify({"error": "uid parameter required"}), 400

    try:
        return jsonify(_ldap_lookup(uid))
    except Exception as exc:
        logger.exception("LDAP lookup failed")
        return jsonify({"error": str(exc)}), 500


# ── Submission helpers ───────────────────────────────────────────────────────

_INVOLVEMENT_MAP = {"none": 0, "occasional": 1, "regular": 2}
_SIGNAL_MAP = {"low": 0, "moderate": 1, "high": 2}


def _get_db_conn() -> Any:
    """Return a new PostgreSQL connection."""
    return psycopg2.connect(DATABASE_URL)


def _json_payload() -> dict:
    """Parse and validate a JSON request body."""
    if not request.is_json:
        raise ValidationError("Request body must be JSON")
    body = request.get_json(silent=True)
    if body is None:
        raise ValidationError("Malformed JSON payload")
    if not isinstance(body, dict) or not body:
        raise ValidationError("Payload must be a non-empty JSON object")
    return body


def _validate_type(value: Any, expected_type: type | tuple[type, ...], path: str) -> None:
    """Raise ValidationError if value is not one of the expected types.

    Supports union types such as ``(int, float)`` and rejects booleans
    when a numeric type is expected (bool is a subclass of int but is not a
    meaningful score or tier threshold).
    """
    types = expected_type if isinstance(expected_type, tuple) else (expected_type,)
    if not isinstance(value, types) or (isinstance(value, bool) and bool not in types):
        type_names = " or ".join(t.__name__ for t in types)
        raise ValidationError(f"{path} must be a {type_names}")


def _validate_non_null_string(value: Any, path: str) -> None:
    """Raise ValidationError if value is not a non-null string."""
    if not isinstance(value, str):
        raise ValidationError(f"{path} must be a non-null string")


def _validate_dashboard_payload(payload: dict) -> None:
    """Validate required DashboardData fields before persistence.

    Reject payloads that would cause a Flutter TypeError when loaded because
    a required String field is null or missing.
    """
    dimensions = payload.get("dimensions")
    if not isinstance(dimensions, list) or len(dimensions) == 0:
        raise ValidationError("Payload must contain a non-empty 'dimensions' array")
    application_domains = payload.get("applicationDomains")
    if not isinstance(application_domains, list) or len(application_domains) == 0:
        raise ValidationError(
            "Payload must contain a non-empty 'applicationDomains' array"
        )

    # Top-level required String fields that Flutter casts with `as String`.
    for field in ("title", "subtitle", "howToRead"):
        _validate_non_null_string(payload.get(field), f"payload.{field}")

    # Dimensions: required numeric/string fields.
    for idx, dim in enumerate(dimensions):
        path = f"dimensions[{idx}]"
        if not isinstance(dim, dict):
            raise ValidationError(f"{path} must be an object")
        for field in ("id", "name", "score", "color", "descriptor"):
            if field not in dim:
                raise ValidationError(f"{path} missing required field '{field}'")
        _validate_type(dim["id"], int, f"{path}.id")
        _validate_non_null_string(dim["name"], f"{path}.name")
        _validate_non_null_string(dim["color"], f"{path}.color")
        _validate_non_null_string(dim["descriptor"], f"{path}.descriptor")
        _validate_type(dim["score"], (int, float), f"{path}.score")

    # Application domains: required fields.
    for idx, domain in enumerate(application_domains):
        path = f"applicationDomains[{idx}]"
        if not isinstance(domain, dict):
            raise ValidationError(f"{path} must be an object")
        for field in (
            "id",
            "name",
            "shortName",
            "applicability",
            "involvement",
            "value",
            "confidence",
            "capabilityIds",
        ):
            if field not in domain:
                raise ValidationError(f"{path} missing required field '{field}'")
        _validate_type(domain["id"], int, f"{path}.id")
        _validate_non_null_string(domain["name"], f"{path}.name")
        _validate_non_null_string(domain["shortName"], f"{path}.shortName")
        _validate_non_null_string(domain["applicability"], f"{path}.applicability")
        _validate_non_null_string(domain["involvement"], f"{path}.involvement")
        _validate_non_null_string(domain["value"], f"{path}.value")
        _validate_non_null_string(domain["confidence"], f"{path}.confidence")
        _validate_type(domain["capabilityIds"], list, f"{path}.capabilityIds")

    # Maturity levels: required String fields.
    maturity_scale = payload.get("maturityScale")
    if isinstance(maturity_scale, list):
        for idx, level in enumerate(maturity_scale):
            path = f"maturityScale[{idx}]"
            if not isinstance(level, dict):
                raise ValidationError(f"{path} must be an object")
            for field in ("level", "label", "color", "description"):
                if field not in level:
                    raise ValidationError(f"{path} missing required field '{field}'")
            _validate_type(level["level"], int, f"{path}.level")
            _validate_non_null_string(level["label"], f"{path}.label")
            _validate_non_null_string(level["color"], f"{path}.color")
            _validate_non_null_string(level["description"], f"{path}.description")

    # Tiers: required String fields.
    tiers = payload.get("tiers")
    if isinstance(tiers, dict):
        for tier_name in ("high", "medium", "low"):
            tier = tiers.get(tier_name)
            if not isinstance(tier, dict):
                raise ValidationError(f"tiers.{tier_name} must be an object")
            for field in ("label", "color", "min"):
                if field not in tier:
                    raise ValidationError(
                        f"tiers.{tier_name} missing required field '{field}'"
                    )
            _validate_non_null_string(tier["label"], f"tiers.{tier_name}.label")
            _validate_non_null_string(tier["color"], f"tiers.{tier_name}.color")
            _validate_type(tier["min"], (int, float), f"tiers.{tier_name}.min")


def _row_to_submission(row: tuple) -> dict:
    """Convert a submissions table row into a JSON-serializable dict."""
    payload = row[7]
    if isinstance(payload, str):
        payload = json.loads(payload)
    return {
        "id": str(row[0]),
        "user_uid": row[1],
        "user_email": row[2] or "",
        "user_display_name": row[3] or "",
        "manager_uid": row[4],
        "department_number": row[5] or "",
        "submitted_at": row[6].isoformat() if row[6] else None,
        "payload": payload,
    }


def _latest_team_submissions(manager_uid: str) -> list:
    """Return the latest submission per user for a given manager."""
    conn = _get_db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT DISTINCT ON (user_uid)
                    id, user_uid, user_email, user_display_name,
                    manager_uid, department_number, submitted_at, payload
                FROM submissions
                WHERE manager_uid = %s
                ORDER BY user_uid, submitted_at DESC
                """,
                (manager_uid,),
            )
            return cur.fetchall()
    finally:
        conn.close()


def _compute_aggregate(rows: list) -> dict:
    """Compute dimension and domain averages from the latest per-user rows."""
    dim_stats: dict = {}
    domain_stats: dict = {}

    for row in rows:
        payload = row[7]
        if isinstance(payload, str):
            payload = json.loads(payload)

        for dim in payload.get("dimensions", []):
            did = dim.get("id")
            if did is None:
                continue
            entry = dim_stats.setdefault(
                did,
                {
                    "id": did,
                    "name": dim.get("name", ""),
                    "color": dim.get("color", ""),
                    "sum": 0.0,
                    "count": 0,
                },
            )
            entry["sum"] += float(dim.get("score", 0.0))
            entry["count"] += 1

        for domain in payload.get("applicationDomains", []):
            did = domain.get("id")
            if did is None:
                continue
            entry = domain_stats.setdefault(
                did,
                {
                    "id": did,
                    "name": domain.get("name", ""),
                    "shortName": domain.get("shortName", ""),
                    "involvement_sum": 0.0,
                    "value_sum": 0.0,
                    "confidence_sum": 0.0,
                    "count": 0,
                    "in_scope_count": 0,
                    "active_count": 0,
                    "not_applicable_count": 0,
                    "capability_ids": set(),
                },
            )
            entry["involvement_sum"] += _INVOLVEMENT_MAP.get(
                domain.get("involvement", "none"), 0
            )
            entry["value_sum"] += _SIGNAL_MAP.get(domain.get("value", "low"), 0)
            entry["confidence_sum"] += _SIGNAL_MAP.get(
                domain.get("confidence", "low"), 0
            )
            entry["count"] += 1
            for cap_id in domain.get("capabilityIds", []) or []:
                entry["capability_ids"].add(cap_id)
            if domain.get("applicability", "in_scope") == "not_applicable":
                entry["not_applicable_count"] += 1
            else:
                entry["in_scope_count"] += 1
                if domain.get("involvement", "none") != "none":
                    entry["active_count"] += 1

    dimensions = []
    for did in sorted(dim_stats):
        s = dim_stats[did]
        dimensions.append(
            {
                "id": s["id"],
                "name": s["name"],
                "color": s["color"],
                "average": round(s["sum"] / s["count"], 1) if s["count"] else 0.0,
            }
        )

    domains = []
    for did in sorted(domain_stats):
        s = domain_stats[did]
        count = s["count"]
        domains.append(
            {
                "id": s["id"],
                "name": s["name"],
                "shortName": s["shortName"],
                "involvement_average": round(s["involvement_sum"] / count, 1)
                if count
                else 0.0,
                "value_average": round(s["value_sum"] / count, 1)
                if count
                else 0.0,
                "confidence_average": round(s["confidence_sum"] / count, 1)
                if count
                else 0.0,
                "in_scope_count": s["in_scope_count"],
                "active_count": s["active_count"],
                "not_applicable_count": s["not_applicable_count"],
                "capability_ids": sorted(s["capability_ids"]),
            }
        )

    return {"member_count": len(rows), "dimensions": dimensions, "domains": domains}


# ── Submissions API ───────────────────────────────────────────────────────────

@app.route("/api/submissions", methods=["POST", "OPTIONS"])
def create_submission() -> Any:
    """Save a new submission snapshot for the authenticated user."""
    if request.method == "OPTIONS":
        return "", 204

    identity = _get_identity()
    manager = _get_manager(identity["uid"])
    payload = _json_payload()
    _validate_dashboard_payload(payload)

    conn = _get_db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO submissions
                    (user_uid, user_email, user_display_name, manager_uid,
                     department_number, payload)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, submitted_at
                """,
                (
                    identity["uid"],
                    identity["email"],
                    identity["name"],
                    manager["manager_uid"],
                    manager["department_number"],
                    json.dumps(payload),
                ),
            )
            row = cur.fetchone()
            conn.commit()
    finally:
        conn.close()

    return jsonify({"id": str(row[0]), "submitted_at": row[1].isoformat()}), 201


@app.route("/api/submissions/me", methods=["GET", "OPTIONS"])
def get_my_submission() -> Any:
    """Return the authenticated user's latest submission."""
    if request.method == "OPTIONS":
        return "", 204

    identity = _get_identity()

    conn = _get_db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_uid, user_email, user_display_name,
                       manager_uid, department_number, submitted_at, payload
                FROM submissions
                WHERE user_uid = %s
                ORDER BY submitted_at DESC
                LIMIT 1
                """,
                (identity["uid"],),
            )
            row = cur.fetchone()
    finally:
        conn.close()

    if row is None:
        raise NotFoundError("No submission found")

    return jsonify(_row_to_submission(row))


@app.route("/api/submissions/team", methods=["GET", "OPTIONS"])
def get_team_submissions() -> Any:
    """Return the latest submission per user for the authenticated user's team."""
    if request.method == "OPTIONS":
        return "", 204

    identity = _get_identity()
    manager = _get_manager(identity["uid"])
    rows = _latest_team_submissions(manager["manager_uid"])

    return jsonify({"submissions": [_row_to_submission(row) for row in rows]})


@app.route("/api/submissions/team/aggregate", methods=["GET", "OPTIONS"])
def get_team_aggregate() -> Any:
    """Return aggregated dimension and domain data for the user's team."""
    if request.method == "OPTIONS":
        return "", 204

    identity = _get_identity()
    manager = _get_manager(identity["uid"])
    rows = _latest_team_submissions(manager["manager_uid"])

    return jsonify(_compute_aggregate(rows))


# ── Catch-all for unknown API paths ───────────────────────────────────────────

@app.route("/api/<path:path>", methods=["GET", "POST", "OPTIONS"])
def api_not_found(path: str) -> Any:
    """Return JSON 404 for any unknown API path."""
    if request.method == "OPTIONS":
        return "", 204
    return jsonify({"error": "Not found"}), 404


# ── Static file serving (local development only) ─────────────────────────────

if SERVE_STATIC:

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def static_files(path: str) -> Any:
        """Serve the Flutter web build; fall back to index.html for SPA routing."""
        file_path = os.path.join(WEB_DIR_ABS, path)
        if path and os.path.isfile(file_path):
            return send_from_directory(WEB_DIR_ABS, path)
        return send_from_directory(WEB_DIR_ABS, "index.html")


# ── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Apply the database schema on startup. This ensures the submissions table
    # and required indexes exist before the API accepts traffic, satisfying both
    # local development and Kubernetes init requirements.
    try:
        init_db.init_db()
    except Exception as exc:
        print(f"ERROR: unable to initialize database: {exc}")
        sys.exit(1)

    if SERVE_STATIC:
        print(f"Serving Flutter app at http://localhost:5000")
        print(f"Web root: {WEB_DIR_ABS}")
    else:
        print("API-only mode: static files are served by the web pod")
    app.run(host="0.0.0.0", port=5000, debug=False)
