# AI Capability Dashboard

A database-backed, team-collaborative Flutter web dashboard for visualizing AI-driven engineering capability across nine dimensions. The app persists submissions to PostgreSQL, derives team aggregates through a Flask backend, and is deployable to Kubernetes behind a Contour ingress.

## Architecture

```mermaid
flowchart LR
    subgraph "Browser"
        A[Flutter Web App]
    end
    subgraph "Kubernetes Namespace: ns-team-ads-test"
        B[Contour HTTPProxy]
        C[Web Pod Nginx]
        D[API Pod Flask]
        E[(Postgres Pod)]
    end
    subgraph "External"
        F[GitHub OAuth]
        G[Adobe LDAP]
    end

    A -->|HTTPS| B
    B -->|static assets| C
    B -->|/api/* /auth| D
    D -->|read/write| E
    D -->|validate token| F
    D -->|manager lookup| G
    A -->|login / token| F
```

The dashboard has three tabs:

- **SDLC Matrix** — Edit the Capability × Domain Links matrix and submit a full snapshot to the backend.
- **Team Capabilities** — Read-only aggregation view showing SDLC Coverage, a radar chart of per-member dimension scores, and the list of submitting teammates.
- **Profile Insights** — Capability profile, Engineering Style Lens, and generated insights derived from the team's aggregated data.

Authentication is handled with GitHub OAuth. The backend validates the Bearer token against GitHub on every authenticated request, derives the user's UID from the primary email, and looks up manager/department information via LDAP.

## Features

- Three-tab Flutter web UI with responsive layouts
- GitHub OAuth login with LDAP-derived manager/department enrichment
- Submit the full SDLC matrix snapshot to PostgreSQL
- Load the latest submission on startup
- Aggregate team submissions by manager-led team
- Radar chart with team average, min-max band, and per-member selection
- Capability profile, style lens, and insight cards driven by aggregate data
- Kubernetes deployment with Contour ingress and TLS

## Prerequisites

- Flutter SDK 3.38.5+ and Dart 3.10.4+
- Python 3.12.3+
- Docker 29.1.3+ and Docker Compose
- kubectl v1.35.0+ with access to the `ethos270-stage-va7` cluster
- A GitHub OAuth app with a valid client ID and secret
- Adobe LDAP reachability for local manager/department lookups

## Environment variables

Copy `.env.example` to `.env` and fill in the real values. `.env` is ignored by git.

| Variable | Purpose | Example |
|---|---|---|
| `GITHUB_CLIENT_ID` | GitHub OAuth app client ID | `YOUR_GITHUB_CLIENT_ID` |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth app client secret | `YOUR_GITHUB_CLIENT_SECRET` |
| `REDIRECT_URI` | OAuth callback URL for local dev | `YOUR_REDIRECT_URI` |
| `LDAP_URL` | Internal LDAP server | `ldap://ldap.loc.adobe.net` |
| `LDAP_BASE_DN` | LDAP search base | `o=adbe` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:postgres@localhost:5432/capability_dashboard` |
| `CORS_ORIGIN` | Allowed origin for API requests | `http://localhost:5000` |
| `WEB_DIR` | Path to Flutter web build | `build/web` |
| `ALLOW_UNVERIFIED_TEST_EMAIL` | Local-dev flag to accept unverified GitHub emails | `false` |

For Kubernetes, the same variables are split between a `ConfigMap` (`k8s/configmap.yaml`) for non-sensitive values and a `Secret` (`k8s/secret.yaml`) for sensitive values. Never commit real secrets to the repository.

## Local setup

1. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

2. Create a Python virtual environment and install backend dependencies:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. Start PostgreSQL:

   ```bash
   docker compose up -d postgres
   ```

4. Copy and fill in the environment file:

   ```bash
   cp .env.example .env
   # Edit .env with real GitHub OAuth credentials and LDAP values.
   ```

5. Build the Flutter web bundle:

   ```bash
   flutter build web --dart-define=GITHUB_CLIENT_ID=$(grep -m1 '^GITHUB_CLIENT_ID=' .env | cut -d= -f2-) \
     --dart-define=REDIRECT_URI=$(grep -m1 '^REDIRECT_URI=' .env | cut -d= -f2-) \
     --dart-define=ALLOW_UNVERIFIED_TEST_EMAIL=$(grep -m1 '^ALLOW_UNVERIFIED_TEST_EMAIL=' .env | cut -d= -f2-)
   ```

## Local run

1. Make sure PostgreSQL is running and `.env` is populated.

2. Start the Flask backend on port 5000:

   ```bash
   source .venv/bin/activate
   python3 server.py
   ```

   The backend serves the Flutter web build from `build/web` when `SERVE_STATIC` is true (the default for local development).

3. Open the app at the `REDIRECT_URI` origin, for example:

   ```
   http://localhost:5000
   ```

   For development with hot reload, you can also run the Flutter dev server on port 3100:

   ```bash
   flutter run -d chrome --web-port 3100 \
     --dart-define=GITHUB_CLIENT_ID=$(grep -m1 '^GITHUB_CLIENT_ID=' .env | cut -d= -f2-) \
     --dart-define=REDIRECT_URI=$(grep -m1 '^REDIRECT_URI=' .env | cut -d= -f2-) \
     --dart-define=ALLOW_UNVERIFIED_TEST_EMAIL=$(grep -m1 '^ALLOW_UNVERIFIED_TEST_EMAIL=' .env | cut -d= -f2-)
   ```

   In that case set `CORS_ORIGIN=http://localhost:3100` in `.env` so the backend accepts requests from the dev server.

## Local test

Run the full test suite and static analysis:

```bash
export GITHUB_CLIENT_ID=$(grep -m1 '^GITHUB_CLIENT_ID=' .env | cut -d= -f2-)
export REDIRECT_URI=$(grep -m1 '^REDIRECT_URI=' .env | cut -d= -f2-)
export ALLOW_UNVERIFIED_TEST_EMAIL=$(grep -m1 '^ALLOW_UNVERIFIED_TEST_EMAIL=' .env | cut -d= -f2-)

flutter analyze
flutter test --dart-define=GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID \
  --dart-define=REDIRECT_URI=$REDIRECT_URI \
  --dart-define=ALLOW_UNVERIFIED_TEST_EMAIL=$ALLOW_UNVERIFIED_TEST_EMAIL

source .venv/bin/activate
pytest
```

Backend tests require a running PostgreSQL instance. The test fixtures use the database configured by `DATABASE_URL`.

## Kubernetes deployment

The manifests live in `k8s/`. They target the `ethos270-stage-va7` cluster and the `ns-team-ads-test` namespace.

### 1. Configure the manifests

- `k8s/configmap.yaml` — non-sensitive values such as `LDAP_URL`, `LDAP_BASE_DN`, `CORS_ORIGIN`, and `ALLOW_UNVERIFIED_TEST_EMAIL`.
- `k8s/secret.yaml` — sensitive values such as `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `REDIRECT_URI`, `DATABASE_URL`, and `POSTGRES_PASSWORD`. The committed file contains placeholders; replace them with real values before applying.
- `k8s/httpproxy.yaml` — the ingress hostname and TLS secret. The current deployment uses:
  - `fqdn: ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net`
  - `tls.secretName: ai-capability-dashboard-tls`

You can regenerate the Secret safely with:

```bash
kubectl create secret generic ai-capability-dashboard-secret \
  --from-literal=GITHUB_CLIENT_ID=YOUR_GITHUB_CLIENT_ID \
  --from-literal=GITHUB_CLIENT_SECRET=YOUR_GITHUB_CLIENT_SECRET \
  --from-literal=REDIRECT_URI=https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/auth \
  --from-literal=DATABASE_URL=YOUR_DATABASE_URL \
  --from-literal=POSTGRES_PASSWORD=YOUR_POSTGRES_PASSWORD \
  -n ns-team-ads-test --dry-run=client -o yaml > k8s/secret.yaml
```

### 2. Build and push container images

The cluster pulls images from the Adobe internal registry. Build, tag, and push both images:

```bash
flutter build web --dart-define=GITHUB_CLIENT_ID=YOUR_GITHUB_CLIENT_ID \
  --dart-define=REDIRECT_URI=https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/auth \
  --dart-define=ALLOW_UNVERIFIED_TEST_EMAIL=true

REG=docker-ads-release.dr-uw2.adobeitc.com

docker build -f api.Dockerfile -t ai-capability-dashboard-api:latest .
docker build -f web.Dockerfile -t ai-capability-dashboard-web:latest .

docker tag ai-capability-dashboard-api:latest $REG/ai-capability-dashboard-api:latest
docker tag ai-capability-dashboard-web:latest $REG/ai-capability-dashboard-web:latest

docker push $REG/ai-capability-dashboard-api:latest
docker push $REG/ai-capability-dashboard-web:latest
```

### 3. Apply the manifests

```bash
kubectl --context ethos270-stage-va7 -n ns-team-ads-test apply -f k8s/
```

### 4. Verify the deployment

Wait for rollouts and check pod readiness:

```bash
kubectl --context ethos270-stage-va7 -n ns-team-ads-test rollout status deployment/api
kubectl --context ethos270-stage-va7 -n ns-team-ads-test rollout status deployment/web
kubectl --context ethos270-stage-va7 -n ns-team-ads-test rollout status deployment/postgres

kubectl --context ethos270-stage-va7 -n ns-team-ads-test get pods,httpproxy,pvc
```

A healthy deployment shows:

- `pod/api-*`, `pod/web-*`, and `pod/postgres-*` as `Running` and `1/1` Ready.
- `persistentvolumeclaim/postgres-pvc` as `Bound`.
- `httpproxy/ai-capability-dashboard` with `STATUS: valid`.

Verify the ingress endpoints:

```bash
curl -sf https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/health
curl -sf https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/
```

## Contour ingress setup

Contour is the Kubernetes ingress controller used for this deployment. It consists of a control plane that watches `HTTPProxy` custom resources and an Envoy data plane that terminates TLS and routes traffic.

The `k8s/httpproxy.yaml` resource exposes the dashboard through a single HTTPS hostname and routes traffic as follows:

| Path prefix | Destination | Purpose |
|---|---|---|
| `/api/*` | `api:5000` | Authenticated backend API routes |
| `/auth` | `api:5000` | GitHub OAuth callback |
| `/health` | `api:5000` | API liveness probe |
| `/ready` | `api:5000` | API readiness probe |
| `/` (catch-all) | `web:80` | Flutter web static assets and SPA fallback |

Because the catch-all `/` route is listed last, any request that does not match `/api/*`, `/auth`, `/health`, or `/ready` is sent to the Nginx web pod. Nginx is configured with `try_files $uri $uri/ /index.html;` so that deep links and page refreshes in the Flutter SPA fall back to `index.html` and the app router handles the path.

TLS is terminated by Envoy using the secret referenced by `tls.secretName: ai-capability-dashboard-tls`. The current deployment uses a self-signed certificate stored in the `ns-team-ads-test` namespace for the FQDN `ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net`.

The `CORS_ORIGIN` value in `k8s/configmap.yaml` and the `REDIRECT_URI` value in `k8s/secret.yaml` must both use the same HTTPS origin as the HTTPProxy FQDN so that GitHub OAuth callbacks route back through the ingress and browser CORS checks pass. For this deployment:

- `CORS_ORIGIN`: `https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net`
- `REDIRECT_URI`: `https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/auth`

## Project structure

```
.
├── lib/                      Flutter source
│   ├── data/                 Default dashboard content and configuration
│   ├── models/               Data types (Dimension, DashboardData, etc.)
│   ├── providers/            State management (AuthNotifier, DashboardNotifier, etc.)
│   ├── theme/                Dashboard styling
│   ├── utils/                Score calculations, URL helpers, CSV/JSON utilities
│   └── widgets/              Dashboard UI (matrix, radar, cards, user menu)
├── test/                     Flutter widget and unit tests
├── server.py                 Flask backend entry point
├── init_db.py                Database initialization helper
├── schema.sql                PostgreSQL schema
├── test_server.py            Backend integration tests
├── test_server_auth_edge_cases.py  Backend auth edge-case tests
├── test_db_schema.py         Database schema tests
├── requirements.txt          Python dependencies
├── docker-compose.yml        Local PostgreSQL service
├── api.Dockerfile            Flask API container image
├── web.Dockerfile            Nginx web container image
├── nginx/default.conf        Nginx SPA fallback configuration
└── k8s/                      Kubernetes manifests
    ├── namespace.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── postgres-*.yaml
    ├── api-*.yaml
    ├── web-*.yaml
    ├── web-configmap.yaml
    └── httpproxy.yaml
```

## Notes

- The backend validates the full `DashboardData` payload on `POST /api/submissions`. Malformed payloads (missing required string fields, non-numeric scores, etc.) are rejected with HTTP 400 before persistence, preventing the Flutter client from loading corrupted snapshots.

## Tech stack

- **Flutter (web)** — UI framework
- **provider** — Flutter state management
- **shared_preferences** — Token persistence in browser localStorage
- **Flask** — Python backend framework
- **psycopg2-binary** — PostgreSQL driver
- **ldap3** — LDAP client for manager/department lookups
- **PostgreSQL 17** — Relational database with JSONB snapshot storage
- **Docker / Docker Compose** — Local database and image builds
- **Kubernetes + Contour** — Production deployment and ingress
