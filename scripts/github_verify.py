#!/usr/bin/env python3
"""GitHub OAuth App login flow verifier.

Usage:
    python3 github_verify.py

Opens the GitHub authorization URL, waits for you to paste the redirect URL
back, exchanges the code for a token, then prints your GitHub user info.

Credentials are read from env vars if set, otherwise fall back to defaults:
    GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET
"""

import json
import os
import secrets
import sys
import urllib.parse
import urllib.request

CLIENT_ID     = os.environ.get("GITHUB_CLIENT_ID",     "Iv23li9PMJlRJ1KJyIVJ")
CLIENT_SECRET = os.environ.get("GITHUB_CLIENT_SECRET", "5d7b3af06e521e15005827fb821d533d59ebdba8")
REDIRECT_URI  = "http://localhost:5000/auth"


def _exchange_code(code: str, state: str) -> dict:
    body = urllib.parse.urlencode({
        "client_id":     CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "code":          code,
        "redirect_uri":  REDIRECT_URI,
        "state":         state,
    }).encode()
    req = urllib.request.Request(
        "https://github.com/login/oauth/access_token",
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept":       "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def _github_get(path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept":        "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def verify():
    state = secrets.token_urlsafe(16)

    auth_url = (
        "https://github.com/login/oauth/authorize"
        f"?client_id={urllib.parse.quote(CLIENT_ID)}"
        f"&redirect_uri={urllib.parse.quote(REDIRECT_URI)}"
        f"&scope=read:user+user:email"
        f"&state={state}"
    )

    print("\n[GITHUB OAUTH]")
    print(f"  App client_id : {CLIENT_ID}")
    print(f"\n  Open this URL in your browser:\n\n  {auth_url}\n")
    print(f"  After authorizing, your browser will redirect to {REDIRECT_URI}?code=...")
    print("  The page may show a connection error — that is fine.")
    print("  Copy the full URL from the address bar and paste it here.\n")

    raw = input("  Paste redirect URL: ").strip()

    parsed = urllib.parse.urlparse(raw)
    params = dict(urllib.parse.parse_qsl(parsed.query))

    if "error" in params:
        print(f"  ERROR: {params['error']} — {params.get('error_description', '')}")
        return False

    if "code" not in params:
        print("  ERROR: No 'code' found in the pasted URL.")
        return False

    if params.get("state") != state:
        print("  ERROR: state mismatch — possible CSRF")
        return False

    print("\n  Exchanging code for access token…")
    try:
        tokens = _exchange_code(params["code"], state)
    except Exception as exc:
        print(f"  Token exchange failed: {exc}")
        return False

    if "error" in tokens:
        print(f"  ERROR: {tokens['error']} — {tokens.get('error_description', '')}")
        return False

    access_token = tokens.get("access_token")
    print(f"  token_type : {tokens.get('token_type')}")
    print(f"  scope      : {tokens.get('scope')}")

    print("\n  Calling /user …")
    try:
        user = _github_get("/user", access_token)
        print(f"    login      : {user.get('login')}")
        print(f"    name       : {user.get('name')}")
        print(f"    id         : {user.get('id')}")
        print(f"    company    : {user.get('company')}")
        print(f"    public repos: {user.get('public_repos')}")
    except Exception as exc:
        print(f"  /user call failed: {exc}")
        return False

    print("\n  Calling /user/emails …")
    try:
        emails = _github_get("/user/emails", access_token)
        for e in emails:
            primary = " (primary)" if e.get("primary") else ""
            print(f"    {e['email']}{primary}")
    except Exception as exc:
        print(f"  /user/emails call failed: {exc}")

    print("\n  [GITHUB] PASS\n")
    return True


if __name__ == "__main__":
    ok = verify()
    sys.exit(0 if ok else 1)
