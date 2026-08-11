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

```bash
flutter build web
REG=docker-ads-release.dr-uw2.adobeitc.com
docker build -f api.Dockerfile -t ai-capability-dashboard-api:latest .
docker build -f web.Dockerfile -t ai-capability-dashboard-web:latest .
docker tag ai-capability-dashboard-api:latest $REG/ai-capability-dashboard-api:latest
docker tag ai-capability-dashboard-web:latest $REG/ai-capability-dashboard-web:latest
docker push $REG/ai-capability-dashboard-api:latest
docker push $REG/ai-capability-dashboard-web:latest
```
