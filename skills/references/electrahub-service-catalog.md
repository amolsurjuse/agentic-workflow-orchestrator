# ElectraHub Service Catalog

Use this reference when mapping an issue, requirement, log line, or regression failure to the owning repository.

## Repository Root

Default local root:

```text
C:\development\project
```

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
| `driver-portal-frontend` | Driver web portal. | Sign-in/sign-up, OAuth buttons, email verification prompt, Sparky entry points. |
| `driver-portal-ios` | Driver iOS app source of truth. | Do not use nested iOS folders elsewhere. |
| `electra-hub-org-page` | Public org/marketing landing page. | Links to admin, driver, simulator, privacy, terms. |
| `ocpi-simulator` | Simulator backend for charger behavior. | OCPP/OCPI simulation behavior and test charger generation. |
| `ocpi-simulator-ui` | Simulator UI. | Real-time DMS display, charger state controls, SOC/cost display. |

## Ownership Rules

- Public route, CORS, or token propagation failure: start with `api-gateway`, then owning service.
- Session stuck, active list wrong, SSE wrong, or stop/start state issue: start with `session-service`, then `ocpp-service`.
- Charger availability or GraphQL charger list wrong: start with `charger-management-service`, `station-management-service`, and `ocpp-service`.
- Admin analytics missing or dashboard values wrong: start with `billing-service`, then `session-service` CDR events and Elasticsearch.
- Push/email notification issue: start with `notification-service`, then producer event source.
- JMeter/TeamCity regression issue: start with `k8s-platform`, then owning backend/client service.
