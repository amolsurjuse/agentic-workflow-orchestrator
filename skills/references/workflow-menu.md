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

1. `00-command-cartographer` — create/approve ElectraHub `/docs/agent-commands.yml`
2. `01-launchpad` — workspace + branch readiness
3. `02-story-forger` — ElectraHub requirement shaping and acceptance criteria
4. `03-impact-mapper` — impacted services, clients, protocols, and dependencies
5. `04-delivery-architect` — implementation plan, validation strategy, rollout/rollback, and gate packet
6. `05-change-builder` — scoped ElectraHub code/config implementation
7. `06-verification-runner` — service/client/protocol validation execution
8. `07-risk-reviewer` — correctness, regression, security, and charging-domain review findings
9. `08-quality-hardener` — apply quality improvements
10. `09-release-scribe` — PR notes, release evidence, and rollout docs
11. `10-release-conductor` — ship/merge workflow

## Shared Standards

- `logging-standard.md` — canonical trace-aware logging, MDC propagation, and sensitive-data rules for all ElectraHub services.
