---
name: agentic-workflow-orchestrator
description: ElectraHub-tuned orchestration system for launch readiness, story shaping, impact mapping, delivery architecture, change building, verification, risk review, release notes, and shipping across EV charging services, clients, OCPP, OCPI, pricing, billing, and Kubernetes operations.
---

# ElectraHub Agentic Workflow Orchestrator

Use this workflow for ElectraHub application delivery. Agents should keep EV charging domain context active: charger/OCPP behavior, OCPI roaming contracts, connector/session state, tariffs, payment/CDR correctness, admin/driver/iOS/Android clients, RBAC/tenant boundaries, and Kubernetes/config governance.

## Feature Flow
`01-launchpad -> 02-story-forger -> 03-impact-mapper -> 04-delivery-architect -> 05-change-builder -> 06-verification-runner -> 07-risk-reviewer -> 08-quality-hardener -> 09-release-scribe -> 10-release-conductor`

## Utility Agents
- `00-command-cartographer`
- `02a-jira-steward`
- `20-system-cartographer`
- `30-refactor-scout`, `31-refactor-designer`
- `40-coverage-sentinel`
- `50-android-mobile` (domain subagent for `DriverPortalAndroid` — Compose / OkHttp / Material 3)
- `90-agent-governor`, `91-instruction-editor`, `92-k8s-capacity-advisor`

## Admin Portal Extension

When the target is admin portal quality + pagination hardening:

- `01-launchpad`: enumerate all UI routes and backend dependencies.
- `02-story-forger`: define acceptance criteria per screen:
  - no console errors/warnings
  - no failing API responses on happy path
  - server-side pagination for list views
- `03-impact-mapper`: map each screen to owning backend service and endpoint.
- `04-delivery-architect`: standardize pagination contract (`limit/offset` or `page/size`) and response metadata.
- `05-change-builder`: implement backend pagination first, then UI wiring.
- `06-verification-runner`: run automated route sweep and capture evidence file.
- `07-risk-reviewer`: flag CORS, RBAC, and schema/contract risks before release.
- `08-quality-hardener`: add regression tests for pagination boundaries and filter/sort interactions.
- `09-release-scribe`: produce per-screen validation summary and unresolved gaps.
- `10-release-conductor`: gate release on zero blocker API/console errors.
