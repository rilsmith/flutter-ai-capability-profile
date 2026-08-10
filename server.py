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
from flask import Flask, jsonify, redirect, request, send_from_directory
from ldap3 import ANONYMOUS, SUBTREE, Connection, Server


# ── Configuration ────────────────────────────────────────────────────────────

REQUIRED_ENV = [
    "GITHUB_CLIENT_ID",
    "GITHUB_CLIENT_SECRET",
    "DATABASE_URL",
]

GITHUB_CLIENT_ID = os.environ.get("GITHUB_CLIENT_ID")
GITHUB_CLIENT_SECRET = os.environ.get("GITHUB_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("REDIRECT_URI", "http://localhost:5000/auth")
LDAP_URL = os.environ.get("LDAP_URL", "ldap://ldap.loc.adobe.net")
LDAP_BASE_DN = os.environ.get("LDAP_BASE_DN", "o=adbe")
DATABASE_URL = os.environ.get("DATABASE_URL")
CORS_ORIGIN = os.environ.get("CORS_ORIGIN", "*")
WEB_DIR = os.environ.get("WEB_DIR", "build/web")

_missing = [name for name in REQUIRED_ENV if not os.environ.get(name)]
if _missing:
    print(f"ERROR: Missing required environment variables: {', '.join(_missing)}")
    sys.exit(1)

WEB_DIR_ABS = os.path.abspath(WEB_DIR)
if not os.path.isdir(WEB_DIR_ABS):
    print(f"ERROR: Flutter web build not found at {WEB_DIR_ABS}")
    print("Run:  flutter build web")
    sys.exit(1)


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


# ── Error handling ────────────────────────────────────────────────────────────

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


# ── Catch-all for unknown API paths ───────────────────────────────────────────

@app.route("/api/<path:path>", methods=["GET", "POST", "OPTIONS"])
def api_not_found(path: str) -> Any:
    """Return JSON 404 for any unknown API path."""
    if request.method == "OPTIONS":
        return "", 204
    return jsonify({"error": "Not found"}), 404


# ── Static file serving (local development only) ─────────────────────────────

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

    print(f"Serving Flutter app at http://localhost:5000")
    print(f"Web root: {WEB_DIR_ABS}")
    app.run(host="0.0.0.0", port=5000, debug=False)
