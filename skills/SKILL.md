---
name: agentic-workflow-orchestrator
description: ElectraHub-tuned orchestration system for launch readiness, story shaping, impact mapping, delivery architecture, change building, verification, risk review, release notes, and shipping across EV charging services, clients, OCPP, OCPI, pricing, billing, and Kubernetes operations.
---

# ElectraHub Agentic Workflow Orchestrator

Use this workflow for ElectraHub application delivery. Agents should keep EV charging domain context active: charger/OCPP behavior, OCPI roaming contracts, connector/session state, tariffs, payment/CDR correctness, admin/driver/iOS clients, RBAC/tenant boundaries, and Kubernetes/config governance.

## Feature Flow
`01-launchpad -> 02-story-forger -> 03-impact-mapper -> 04-delivery-architect -> 05-change-builder -> 06-verification-runner -> 07-risk-reviewer -> 08-quality-hardener -> 09-release-scribe -> 10-release-conductor`

## Utility Agents
- `00-command-cartographer`
- `02a-jira-steward`
- `20-system-cartographer`
- `30-refactor-scout`, `31-refactor-designer`
- `40-coverage-sentinel`, `41-regression-sentinel`
- `90-agent-governor`, `91-instruction-editor`, `92-k8s-capacity-advisor`, `93-observability-sentinel`

## Shared References
- `electrahub-service-catalog.md` - repository ownership and service/client map.
- `current-platform-state.md` - current dev/prod, Cloudflare, k3d, Argo, TeamCity, observability, and charging-flow assumptions.
- `logging-standard.md` - trace-aware logging and sensitive-data rules.
- `observability-playbook.md` - Splunk/Grafana/Kubernetes incident triage.
- `regression-playbook.md` - charging, SSE, OCPP/OCPI, CDR, dashboard, and JMeter validation.
