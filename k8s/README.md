# Kubernetes manifests

These manifests deploy the AI Capability Dashboard to the `ns-team-ads-test`
namespace on the `ethos270-stage-va7` context.

## Placeholders

Before applying the manifests, replace the placeholder values in:

- `configmap.yaml` — LDAP URL/base DN, CORS origin, and web directory.
- `secret.yaml` — placeholder GitHub OAuth credentials, redirect URI,
  database URL, and Postgres password. The placeholder values are committed
  so that no real secrets are tracked. Replace/update with:

  ```bash
  kubectl create secret generic ai-capability-dashboard-secret \
    --from-literal=GITHUB_CLIENT_ID=... \
    --from-literal=GITHUB_CLIENT_SECRET=... \
    --from-literal=REDIRECT_URI=... \
    --from-literal=DATABASE_URL=... \
    --from-literal=POSTGRES_PASSWORD=... \
    -n ns-team-ads-test --dry-run=client -o yaml > k8s/secret.yaml
  ```

- `httpproxy.yaml` — the ingress hostname and TLS secret name.

## Traffic routing

The Contour `HTTPProxy` routes:

- `/api/*` to the API service on port 5000.
- `/auth` to the API service on port 5000.
- All other traffic to the web (Nginx) service on port 80.

The web pod is configured to fall back to `index.html` for any route that does
not match a static asset, which supports Flutter SPA deep links and page
refreshes.

## Container images

The API and web deployments use locally built images:

- `ai-capability-dashboard-api:latest`
- `ai-capability-dashboard-web:latest`

Both deployments set `imagePullPolicy: IfNotPresent` so the cluster uses the
locally loaded images instead of trying to pull from a remote registry.
