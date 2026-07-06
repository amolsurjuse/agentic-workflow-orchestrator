# ElectraHub Service Catalog

Use this reference when mapping an issue, requirement, log line, or regression failure to the owning repository.

## Repository Root

Default local root:

```text
C:\development\project
```

## Canonical Repositories

Use these repository names and Git URLs when cloning, checking ownership, or preparing workspace context. Work normally happens on `develop` unless the service is explicitly configured otherwise in `k8s-platform` TeamCity pipeline definitions.

| Repo | Git URL | Notes |
| --- | --- | --- |
| `admin-portal-ui` | `git@github.com:amolsurjuse/admin-portal-ui.git` | Admin/operator frontend. Correct spelling is `admin-portal-ui`. |
| `agentic-workflow-orchestrator` | `git@github.com:amolsurjuse/agentic-workflow-orchestrator.git` | Central agent workflow package and shared references. |
| `api-gateway` | `git@github.com:amolsurjuse/api-gateway.git` | Public API edge. |
| `auth-service` | `git@github.com:amolsurjuse/auth-service.git` | Authentication and auth lifecycle. |
| `billing-service` | `git@github.com:amolsurjuse/billing-service.git` | Billing/CDR/analytics facts. |
| `charger-management-service` | `git@github.com:amolsurjuse/charger-management-service.git` | Charger/location discovery and charger-facing APIs. |
| `driver-portal-ios` | `git@github.com:amolsurjuse/driver-portal-ios.git` | Driver iOS app. |
| `electra-hub-org-page` | `git@github.com:amolsurjuse/electra-hub-org-page.git` | Public web presence. |
| `k8s-platform` | `git@github.com:amolsurjuse/k8s-platform.git` | Current deployment, TeamCity, Argo, Helm, infra, and JMeter source of truth. |
| `kubernetes` | `git@github.com:amolsurjuse/kubernetes.git` | Legacy/imported Kubernetes artifacts; prefer `k8s-platform` for current delivery. |
| `notification-service` | `git@github.com:amolsurjuse/notification-service.git` | Email/push notification service. |
| `ocpi-service` | `git@github.com:amolsurjuse/ocpi-service.git` | OCPI partner/roaming service. |
| `ocpi-simulator` | `git@github.com:amolsurjuse/ocpi-simulator.git` | Simulator backend and the integrated Angular UI under `ui/`. |
| `ocpi-simulator-ui` | `git@github.com:amolsurjuse/ocpi-simulator-ui.git` | Standalone simulator UI repo; verify deployment ownership before editing. Current TeamCity config builds simulator UI from `ocpi-simulator/ui`. |
| `ocpp-service` | `git@github.com:amolsurjuse/ocpp-service.git` | OCPP protocol service. |
| `payment-service` | `git@github.com:amolsurjuse/payment-service.git` | Wallet/card/payment state. |
| `pricing-service` | `git@github.com:amolsurjuse/pricing-service.git` | Tariffs and pricing. |
| `session-service` | `git@github.com:amolsurjuse/session-service.git` | Charging session lifecycle. |
| `station-management-service` | `git@github.com:amolsurjuse/station-management-service.git` | Station/topology/status service. |
| `subscription-service` | `git@github.com:amolsurjuse/subscription-service.git` | Driver/admin subscription logic. |
| `user-service` | `git@github.com:amolsurjuse/user-service.git` | User profile and roles. |
| `web-socket-connector` | `git@github.com:amolsurjuse/web-socket-connector.git` | Simulator/OCPP WebSocket bridge. TeamCity currently tracks `main` for this repo. |

## Platform And Delivery

| Repo | Purpose |
| --- | --- |
| `k8s-platform` | Helm values, Argo CD applications, Cloudflare tunnel/service config, TeamCity pipeline scripts, JMeter suites, Kubernetes runtime config. |
| `kubernetes` | Older or imported Kubernetes artifacts. Prefer `k8s-platform` when both contain equivalent deployment intent. |
| `agentic-workflow-orchestrator` | Central ElectraHub agent workflow, skills, shared references, and installation templates. |

## Backend Services

| Repo | Runtime role | High-risk domains |
| --- | --- | --- |
| `api-gateway` | Public API routing, auth propagation, CORS, proxying to backend services. | JWT, refresh flow, route ordering, CORS, trace propagation. |
| `auth-service` | Login, refresh token, OAuth, terms acceptance, email verification, auth events. | 401/403/451 semantics, refresh token cookie/body handling, OAuth verified email. |
| `user-service` | User profile, roles, admin users, driver identity, wallet provisioning integration. | RBAC, customer/system-admin separation, read-only admin behavior. |
| `session-service` | Charging session lifecycle, SSE, OCPP callbacks, start/stop, CDR events. | Session state machine, connector concurrency, idempotency, meter/cost updates. |
| `ocpp-service` | Charger WebSocket/OCPP protocol handling and remote command routing. | Heartbeat, status notification, remote start/stop, meter values, live charger connection ownership. |
| `charger-management-service` | OCPI charger/location discovery and GraphQL charger data. | Charger availability, geo-filtering, connector availability, tariff projection. |
| `station-management-service` | Station and charger topology/state. | Charger/connector status consistency, offline propagation. |
| `billing-service` | CDR processing, invoice/analytics facts, dashboard aggregation, Elasticsearch indexing. | Revenue correctness, CDR idempotency, ES dashboards, Kafka/Rabbit events. |
| `payment-service` | Wallet, cards, holds, settlement, payment state. | Wallet balance, holds, settlement, stale authorization cleanup. |
| `pricing-service` | Tariffs and pricing calculations. | Real-time cost, tariff lookup, currency, tax/rounding. |
| `notification-service` | Email/push/SMS notification orchestration. | Firebase device registration, quotas, email verification, receipts. |
| `ai-support-service` | Sparky support chat and diagnostic lookup orchestration. | LLM quota/fallback, tool context, auth/RBAC. |
| `ocpi-service` | OCPI partner/roaming APIs. | OCPI compatibility and partner payload contracts. |
| `subscription-service` | Subscriptions and audit logs. | Admin APIs, validation, audit visibility. |
| `web-socket-connector` | WebSocket connector service. | Runtime dependency support, Go toolchain if applicable. |

## Client Applications

| Repo | Purpose | Notes |
| --- | --- | --- |
| `admin-portal-ui` | Operator/admin dashboard and management UI. | Must support read-only admin mode and dashboard analytics from backend facts. |
| `driver-portal-ios` | Driver iOS app source of truth. | Do not use nested iOS folders elsewhere. |
| `electra-hub-org-page` | Public org/marketing landing page. | Links to admin, driver, simulator, privacy, terms. |
| `ocpi-simulator` | Simulator backend for charger behavior plus integrated Angular UI in `ui/`. | OCPP/OCPI simulation behavior, test charger generation, connector operations UI. Current deployment builds `ocpp-simulator-ui` from this repo's `ui/` folder. |
| `ocpi-simulator-ui` | Standalone simulator UI repo. | Treat as secondary/legacy unless `k8s-platform` build config points to it for the target environment. |

## Ownership Rules

- Public route, CORS, or token propagation failure: start with `api-gateway`, then owning service.
- Session stuck, active list wrong, SSE wrong, or stop/start state issue: start with `session-service`, then `ocpp-service`.
- Charger availability or GraphQL charger list wrong: start with `charger-management-service`, `station-management-service`, and `ocpp-service`.
- Admin analytics missing or dashboard values wrong: start with `billing-service`, then `session-service` CDR events and Elasticsearch.
- Push/email notification issue: start with `notification-service`, then producer event source.
- JMeter/TeamCity regression issue: start with `k8s-platform`, then owning backend/client service.
- Simulator UI issue: first check `k8s-platform` TeamCity config. If it builds from `ocpi-simulator` with `appDir: ui`, edit `ocpi-simulator/ui`, not the standalone `ocpi-simulator-ui` repo.
- Simulator unplug, connector status, OCPP event, or controlled transaction issue: start with `ocpi-simulator`, then `web-socket-connector`, `ocpp-service`, and `session-service` depending on where the event disappears.
