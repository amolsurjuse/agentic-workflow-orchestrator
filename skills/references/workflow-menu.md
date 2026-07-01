# ElectraHub Workflow Menu Prompts

## Start Feature Flow

```text
Run ElectraHub feature workflow for <WORK_ID or requirement description>.
Start at 01-launchpad and follow the standard handoff chain.
If no Jira key is provided, generate a local `REQ-<YYYYMMDD>-<slug>` work id and continue from the description.
Use token-saver mode: fixed root path from /docs/agent-commands.yml paths.root and no broad repo scans.
Keep ElectraHub context active: OCPP, OCPI, connector/session state, tariff/pricing, payment/CDR, RBAC/tenant boundaries, client impact, and Kubernetes/config governance.
```

## Quick Agent Targets

1. `00-command-cartographer` - create/approve ElectraHub `/docs/agent-commands.yml`
2. `01-launchpad` - workspace + branch readiness
3. `02-story-forger` - ElectraHub requirement shaping and acceptance criteria
4. `03-impact-mapper` - impacted services, clients, protocols, and dependencies
5. `04-delivery-architect` - implementation plan, validation strategy, rollout/rollback, and gate packet
6. `05-change-builder` - scoped ElectraHub code/config implementation
7. `06-verification-runner` - service/client/protocol validation execution
8. `07-risk-reviewer` - correctness, regression, security, and charging-domain review findings
9. `08-quality-hardener` - apply quality improvements
10. `09-release-scribe` - PR notes, release evidence, and rollout docs
11. `10-release-conductor` - ship/merge workflow
12. `41-regression-sentinel` - charging-flow, JMeter, SSE, OCPP/OCPI, CDR, and dashboard regression checks
13. `93-observability-sentinel` - Splunk/Grafana/Kubernetes log, trace, warning, and incident triage

## Shared Standards

- `logging-standard.md` - canonical trace-aware logging, MDC propagation, and sensitive-data rules for all ElectraHub services.
- `electrahub-service-catalog.md` - current repo ownership and service/client map.
- `current-platform-state.md` - current dev/prod, k3d, Cloudflare, TeamCity, Argo, Splunk, Grafana, and protocol assumptions.
- `observability-playbook.md` - Splunk/Grafana incident triage and fix routing.
- `regression-playbook.md` - end-to-end charging regression and JMeter interpretation.

## Incident / Operations Prompts

```text
Run 93-observability-sentinel for <Splunk URL/export/trace id/symptom>.
Use references/observability-playbook.md, references/logging-standard.md, and references/electrahub-service-catalog.md.
Identify root cause versus cascading symptoms, then route the smallest safe fix.
```

```text
Run 41-regression-sentinel for <TeamCity build URL/JMeter output/charging symptom>.
Use references/regression-playbook.md and validate login, charger discovery, session start, SSE, OCPP meter values, stop, CDR, and dashboard analytics.
```
