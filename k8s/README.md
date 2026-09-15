# Kubernetes manifests

These manifests deploy the AI Capability Dashboard to the `ns-team-ads-test`
namespace on the `ethos270-stage-va7` context.

## Placeholders

Before applying the manifests, replace the placeholder values in:

- `configmap.yaml` — LDAP URL/base DN, CORS origin, and web directory.
  `CORS_ORIGIN` must match the HTTPS origin of the HTTPProxy fqdn:
  `https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net`.
- `secret.yaml` — placeholder GitHub OAuth credentials, redirect URI,
  database URL, and Postgres password. `REDIRECT_URI` must use the same
  HTTPS origin as the HTTPProxy fqdn so GitHub OAuth callbacks route back
  through the ingress:
  `https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/auth`.
  Also set `LDAP_BIND_DN` / `LDAP_PASSWORD`: since the 2026-08 SailPoint
  identity sync, the LDAP directory hides the `manager` attribute from
  anonymous readers, so the team endpoints require an authenticated bind.
  Use an LDAP service account, not a personal credential.
- `secret.yaml` — placeholder GitHub OAuth credentials, redirect URI,
  database URL, and Postgres password. The placeholder values are committed
  so that no real secrets are tracked. Replace/update with:

  ```bash
  kubectl create secret generic ai-capability-dashboard-secret \
    --from-literal=GITHUB_CLIENT_ID=... \
    --from-literal=GITHUB_CLIENT_SECRET=... \
    --from-literal=REDIRECT_URI=https://ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net/auth \
    --from-literal=DATABASE_URL=... \
    --from-literal=POSTGRES_PASSWORD=... \
    -n ns-team-ads-test --dry-run=client -o yaml > k8s/secret.yaml
  ```

- `httpproxy.yaml` — the ingress hostname and TLS secret name.
  The current deployment uses:
  - `fqdn: ai-capability-dashboard.corp.ethos270-stage-va7.ethos.adobe.net`
  - `tls.secretName: ai-capability-dashboard-tls`
  The TLS secret is created in the `ns-team-ads-test` namespace with a
  self-signed certificate for the chosen hostname. Update the fqdn and
  regenerate the TLS secret if a different hostname or a cluster-provisioned
  certificate is required.

## Postgres data directory

The Postgres deployment sets `PGDATA` to `/var/lib/postgresql/data/pgdata`
so that Postgres initializes a subdirectory under the PVC mount point rather
than the mount point itself, which avoids an `initdb` failure caused by the
`lost+found` directory on the volume.

## Traffic routing

The Contour `HTTPProxy` routes:

- `/api/*` to the API service on port 5000.
- `/auth` to the API service on port 5000.
- All other traffic to the web (Nginx) service on port 80.

The web pod is configured to fall back to `index.html` for any route that does
not match a static asset, which supports Flutter SPA deep links and page
refreshes.

## Container images

The API and web images are built locally and pushed to the Adobe internal
registry so the `ethos270-stage-va7` cluster can pull them:

- `docker-ads-release.dr-uw2.adobeitc.com/ai-capability-dashboard-api:latest`
- `docker-ads-release.dr-uw2.adobeitc.com/ai-capability-dashboard-web:latest`

Both deployments set `imagePullPolicy: IfNotPresent` and reference the
`docker-ads-release-auth` image pull secret so the cluster resolves the images
from the Adobe registry rather than attempting to pull from Docker Hub.

To rebuild and push:

**Warning:** the web app reads `GITHUB_CLIENT_ID` and `REDIRECT_URI` at
compile time (`String.fromEnvironment`). Do NOT build with the values from
`.env` — its `REDIRECT_URI` (`http://localhost:5000/auth`) is for local dev
only. A web build without the correct defines deploys fine but shows
"GitHub OAuth is not configured" with a disabled login button. Always pass
the cluster redirect URI explicitly:

```bash
flutter build web \
  --dart-define=GITHUB_CLIENT_ID=YOUR_GITHUB_CLIENT_ID \
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

Then restart the deployments so the pods pull the new `latest` images:

```bash
kubectl rollout restart deployment/api deployment/web -n ns-team-ads-test --context ethos270-stage-va7
kubectl rollout status deployment/api -n ns-team-ads-test --context ethos270-stage-va7
kubectl rollout status deployment/web -n ns-team-ads-test --context ethos270-stage-va7
```

## Authenticating kubectl (WSL)

Cluster auth uses `kubelogin` with Azure AD. The `ethos270-stage-va7`
context uses the interactive login flow, which opens a browser — this fails
out of the box in WSL because there is no `xdg-open`.

Fix (one-time): a shim at `~/bin/xdg-open` (already on `PATH`) forwards
browser-open requests to the Windows default browser:

```sh
#!/bin/sh
# Forward open requests to the Windows default browser via WSL interop.
# PowerShell Start-Process exits 0 on success (explorer.exe exits 1 even
# when it opens the URL, which callers treat as failure).
exec /mnt/c/Windows/system32/windowspowershell/v1.0/powershell.exe \
  -NoProfile -Command "Start-Process -FilePath '$*'"
```

Notes:

- `cmd.exe /c start` cannot be used because `&` in OAuth URLs is
  misinterpreted by cmd.exe; `explorer.exe` exits 1 even on success, which
  azidentity treats as an auth failure.
- The kubeconfig comes from the internal repo
  `git.corp.adobe.com:adobe-platform/k8s-kubeconfig` (see its README). If
  auth breaks, pull a fresh copy of `kubeconfig.yaml` from there rather than
  hand-editing `~/.kube/config` — it already matches the canonical config.
  Tokens remain valid until the AdobeNet password changes.
- Tokens are cached in `~/.kube/cache/kubelogin/`; deleting that directory
  forces a fresh sign-in.
- No `current-context` is set, so pass `--context ethos270-stage-va7`
  explicitly on every kubectl call.
