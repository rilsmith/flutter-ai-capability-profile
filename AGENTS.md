# AGENTS.md

Notes for AI coding agents working in this repository.

## Project

Flutter web app (AI/SDLC capability dashboard) with a Python Flask backend
(`server.py`, PostgreSQL). State management uses `provider`.

## Validation

- `flutter analyze` — must pass with no issues.
- `flutter test` — full suite lives in `test/`.
- Python API tests: `pytest test_server.py` (uses a local pytest harness; see
  also `test_db_schema.py` and `test_server_auth_edge_cases.py`).

## Deployment

Full procedure: `k8s/README.md`. Short version:

1. `flutter build web`
2. Build/tag/push both images to `docker-ads-release.dr-uw2.adobeitc.com`
   (commands in k8s/README.md).
3. `kubectl rollout restart deployment/api deployment/web -n ns-team-ads-test --context ethos270-stage-va7`

Always pass `--context ethos270-stage-va7` explicitly; no `current-context`
is set. kubectl auth (Azure AD via kubelogin) needs the `~/bin/xdg-open`
browser shim from WSL — see "Authenticating kubectl (WSL)" in k8s/README.md.

## Conventions

- Backend domain logic lives in `server.py`; dashboard defaults (dimensions,
  domains) in `lib/data/defaults.dart`.
- Aggregate endpoints compute per-user latest submissions server-side
  (`_compute_aggregate`); some client-side aggregations (e.g. capability-link
  counts for the team heatmap) are computed in
  `lib/providers/team_notifier.dart` from raw submission payloads.
