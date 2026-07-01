# Current ElectraHub Platform State

Use this reference to avoid stale assumptions about the running platform.

## Runtime Topology

- Development and production are currently hosted from a Windows/WSL2/k3d environment.
- Cloudflare Tunnel routes public domains into k3d ingress.
- Primary public hosts include:
  - `https://dev.electrahub.net`
  - `https://electrahub.net`
  - `https://api.dev.electrahub.net`
  - `https://api.electrahub.net`
  - `https://argocd-dev.electrahub.net`
  - `https://argocd.electrahub.net`
  - `https://admin-portal.electrahub.net`
  - `https://driver-portal.electrahub.net`
  - `https://ocpp-simulator.electrahub.net`

## Source Control And Delivery

- Work happens primarily on `develop` branches.
- TeamCity builds Docker images and drives CI/CD pipelines.
- Argo CD deploys dev and prod applications.
- Prod Argo should generally avoid autosync for service promotion unless explicitly changed.

## Observability

- Splunk is used for central log search.
- Grafana is used for runtime dashboards.
- Logs must include `traceId` and `spanId`.
- Known operational noise that should not become application bugs by itself:
  - expired JWTs from normal client lifecycle
  - SSE client disconnects/timeouts
  - stale OCPP meter callbacks after a failed or already-reconciled transaction
  - Elasticsearch clock jitter in WSL/k3d

## Charging Flow Truths

- Driver clients must send OCPP charger identity in `chargerId`.
- OCPI location id must be sent separately as `locationId`.
- Connector id must preserve the backend string identifier.
- Connector number is protocol numeric connector identity and must not be inferred from charger sequence.
- Session start must not return old stopped or finishing sessions as `ALREADY_ACTIVE`.
- Same connector concurrency must allow only one non-terminal active session.
- Stop flow must reconcile `FINISHING` sessions if the charger never sends `StopTransaction`.
- Real-time cost and energy come from OCPP meter/session processing, then flow to SSE and dashboard/analytics.

## Analytics Truths

- Admin dashboard should be backed by billing/analytics facts, not raw assumptions from one service table.
- Completed session CDR events should feed billing analytics and Elasticsearch-backed dashboard views.
- Missing dashboard data requires checking event production, event consumption, CDR fact persistence, ES indexing, and API query windows.

## Notification Truths

- Notification-service supports email and push channels.
- Firebase push requires registered device tokens.
- Email may be disabled or quota-limited by environment.
- Transactional notifications such as verification, password reset, charging start/stop, battery full, idle warnings, and receipts must be treated separately from promotional/rate-limited events.
