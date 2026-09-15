#!/usr/bin/env python3
"""Okta OAuth2 Authorization Code + PKCE login flow verifier.

Usage:
    python3 okta_verify.py [stage|preview]

Defaults to 'stage'. Opens a browser, captures the callback on :5000,
exchanges the code for tokens, and prints the ID token claims.
"""

import base64
import hashlib
import http.server
import json
import os
import secrets
import sys
import threading
import urllib.parse
import urllib.request
import webbrowser

CONFIGS = {
    "stage": {
        "domain":    "https://adobe-stage.okta.com",
        "client_id": "0oa25uc7nri7LX3KI1d8",
    },
    "preview": {
        "domain":    "https://adobe.oktapreview.com",
        "client_id": "0oa2t5rzd4qFzmyiS0h8",
    },
}

REDIRECT_URI  = "http://localhost:5000"
CALLBACK_PATH = "/"
PORT          = 5000


# ── PKCE helpers ─────────────────────────────────────────────────────────────

def _pkce_pair():
    verifier  = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).rstrip(b"=").decode()
    return verifier, challenge


# ── Local callback server ─────────────────────────────────────────────────────

_callback_result: dict = {}


class _Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = dict(urllib.parse.parse_qsl(parsed.query))
        _callback_result.update(params)

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        if "code" in params:
            body = "<h2>Authorization code received — you can close this tab.</h2>"
        else:
            body = f"<h2>Error: {params.get('error', 'unknown')}</h2><pre>{params}</pre>"
        self.wfile.write(body.encode())

    def log_message(self, *_):  # silence access logs
        pass


def _run_server(server):
    server.handle_request()  # serve exactly one request then stop


# ── Token exchange ────────────────────────────────────────────────────────────

def _exchange_code(domain, client_id, code, verifier):
    token_url = f"{domain}/oauth2/v1/token"
    body = urllib.parse.urlencode({
        "grant_type":    "authorization_code",
        "client_id":     client_id,
        "redirect_uri":  REDIRECT_URI,
        "code":          code,
        "code_verifier": verifier,
    }).encode()
    req = urllib.request.Request(token_url, data=body, headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept":       "application/json",
    })
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def _decode_jwt_payload(token):
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)  # re-pad
    return json.loads(base64.urlsafe_b64decode(payload))


def _userinfo(domain, access_token):
    req = urllib.request.Request(
        f"{domain}/oauth2/v1/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


# ── Main ──────────────────────────────────────────────────────────────────────

def verify(env: str):
    cfg       = CONFIGS[env]
    domain    = cfg["domain"]
    client_id = cfg["client_id"]

    verifier, challenge = _pkce_pair()
    state = secrets.token_urlsafe(16)

    auth_url = (
        f"{domain}/oauth2/v1/authorize"
        f"?response_type=code"
        f"&client_id={urllib.parse.quote(client_id)}"
        f"&redirect_uri={urllib.parse.quote(REDIRECT_URI)}"
        f"&scope=openid+profile+email"
        f"&state={state}"
        f"&code_challenge={challenge}"
        f"&code_challenge_method=S256"
    )

    print(f"\n[{env.upper()}] {domain}")
    print(f"  client_id : {client_id}")
    print(f"\n  Open this URL in your browser:\n\n  {auth_url}\n")

    print("  After login, your browser will try to load http://localhost:5000/?code=...")
    print("  The page may show a connection error — that is fine.")
    print("  Copy the full URL from your browser's address bar and paste it here.\n")
    raw = input("  Paste redirect URL: ").strip()

    parsed  = urllib.parse.urlparse(raw)
    params  = dict(urllib.parse.parse_qsl(parsed.query))
    _callback_result.update(params)

    if "error" in _callback_result:
        print(f"  ERROR: {_callback_result['error']} — {_callback_result.get('error_description', '')}")
        return False

    if "code" not in _callback_result:
        print("  ERROR: No 'code' found in the pasted URL.")
        return False

    if _callback_result.get("state") != state:
        print("  ERROR: state mismatch — possible CSRF")
        return False

    print("  Authorization code received. Exchanging for tokens…")
    try:
        tokens = _exchange_code(domain, client_id, _callback_result["code"], verifier)
    except Exception as exc:
        print(f"  Token exchange failed: {exc}")
        return False

    print("\n  Tokens received:")
    for k in ("token_type", "expires_in", "scope"):
        if k in tokens:
            print(f"    {k}: {tokens[k]}")

    if "id_token" in tokens:
        claims = _decode_jwt_payload(tokens["id_token"])
        print("\n  ID token claims:")
        for k, v in claims.items():
            print(f"    {k}: {v}")

    if "access_token" in tokens:
        try:
            info = _userinfo(domain, tokens["access_token"])
            print("\n  /userinfo response:")
            for k, v in info.items():
                print(f"    {k}: {v}")
        except Exception as exc:
            print(f"  /userinfo call failed: {exc}")

    print(f"\n  [{env.upper()}] PASS\n")
    return True


if __name__ == "__main__":
    env = sys.argv[1] if len(sys.argv) > 1 else "stage"
    if env not in CONFIGS:
        print(f"Unknown env '{env}'. Choose: {', '.join(CONFIGS)}")
        sys.exit(1)
    ok = verify(env)
    sys.exit(0 if ok else 1)
