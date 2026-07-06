# ElectraHub Agentic Workflow Orchestrator

ElectraHub Agentic Workflow Orchestrator is a Codex/GitHub agent package for running a structured delivery workflow across ElectraHub applications. It installs a sequenced set of agents into a target ElectraHub repository and gives those agents shared rules, handoff files, command mappings, repository references, and templates so feature work can move from chat requirement capture through implementation, validation, review, hardening, documentation, and release.

The workflow is tailored for ElectraHub domains such as EV charging backend services, admin and driver clients, OCPP charger integrations, OCPI roaming integrations, station management, pricing, billing, sessions, connector status, payments, CDRs, RBAC, tenant behavior, and Kubernetes-backed operations.

## What This Repository Provides

- Sequenced ElectraHub delivery agents under `.github/agents/`.
- Matching Codex skill instructions under `skills/agents/`.
- Shared repo-wide references under `skills/references/`, including the ElectraHub service catalog and logging standard.
- Operational utility agents for Splunk/Grafana incident triage and charging-flow/JMeter regression validation.
- Bundled helper scripts under `skills/scripts/` that are installed to `.github/agents/scripts/`.
- Shared rules that every agent must read before acting.
- A setup script that installs the agent package into a target ElectraHub repository without external issue-tracker configuration.
- Project templates for command mappings, pull request notes, and project context.
- Chat-first requirement capture with generated local work ids.

## Requirement Input Mode

The workflow starts from the requirement text provided in chat.

```text
@01-launchpad add charger tariff preview to the station management UI
```

`01-launchpad` creates a local requirement id from the date and description.

```text
WORK_ID=REQ-20260705-add-charger-tariff-preview
```

All agent handoffs and outputs are written under:

```text
/agentWork/<WORK_ID>/
```

If the user includes an external ticket id, agents preserve it as plain text context only. Core workflow agents do not fetch, create, or update external issue tracker records.

## Launchpad Preparation Gate

`01-launchpad` is the mandatory first step for feature delivery. It must finish these checks before handing off:

- Verify terminal readiness.
- Verify required tools: Git, Node.js, npm, Python, JDK, Maven, and Docker.
- Install missing required tools through the approved workspace or OS package manager when possible, then re-check versions.
- Read `skills/references/electrahub-service-catalog.md`.
- Check out missing canonical ElectraHub repositories into the configured workspace root.
- Fetch existing repositories and record branch plus dirty/clean state without discarding local work.
- Capture the requirement from chat and generate `REQ-<YYYYMMDD>-<slug>`.
- Persist `/agentWork/<WORK_ID>/01-launchpad.out.<RUN>.md` with the toolchain and repository checkout matrix.

## Main Feature Workflow

```text
01-launchpad
  -> 02-story-forger
  -> 03-impact-mapper
  -> 04-delivery-architect
  -> 05-change-builder
  -> 06-verification-runner
  -> 07-risk-reviewer
  -> 08-quality-hardener
  -> 09-release-scribe
  -> 10-release-conductor
  -> optional 10a-conflict-stabilizer
```

## Agents

| Sequence | Runtime agent | Purpose |
| --- | --- | --- |
| 00 | `00-command-cartographer` | Builds and maintains `/docs/agent-commands.yml` after user approval. |
| 01 | `01-launchpad` | Prepares the workspace, checks out ElectraHub repositories, verifies tools, and captures the chat requirement. |
| 02 | `02-story-forger` | Converts the chat requirement into an implementation-ready story. |
| 03 | `03-impact-mapper` | Maps impacted services, clients, APIs, data, tests, and Kubernetes areas. |
| 04 | `04-delivery-architect` | Produces the implementation plan and sequencing. |
| 05 | `05-change-builder` | Implements the approved code changes. |
| 06 | `06-verification-runner` | Runs repository-specific validation commands. |
| 07 | `07-risk-reviewer` | Reviews changes for bugs, risks, regressions, and test gaps. |
| 08 | `08-quality-hardener` | Applies follow-up fixes from review and validation. |
| 09 | `09-release-scribe` | Prepares PR notes, release notes, and handoff documentation. |
| 10 | `10-release-conductor` | Handles final readiness and release coordination. |
| 10a | `10a-conflict-stabilizer` | Resolves merge conflicts or branch stabilization issues. |
| 20 | `20-system-cartographer` | Produces architecture and system understanding artifacts. |
| 30 | `30-refactor-scout` | Finds refactor opportunities and quality improvement areas. |
| 31 | `31-refactor-designer` | Designs refactor plans before implementation. |
| 40 | `40-coverage-sentinel` | Reviews test coverage and recommends focused coverage work. |
| 41 | `41-regression-sentinel` | Runs and interprets charging-flow, JMeter, SSE, OCPP/OCPI, CDR, and dashboard regression checks. |
| 90 | `90-agent-governor` | Maintains agent governance and workflow consistency. |
| 91 | `91-instruction-editor` | Updates agent instructions safely. |
| 92 | `92-k8s-capacity-advisor` | Reviews Kubernetes resource and capacity concerns. |
| 93 | `93-observability-sentinel` | Investigates Splunk/Grafana/Kubernetes logs, traces, warnings, and production incidents. |

## Install Into an ElectraHub Repository

Run the setup script from the target ElectraHub repository root:

```bash
bash /path/to/agentic-workflow-orchestrator/scripts/setup-agents.sh
```

Or pass the target path explicitly:

```bash
bash /path/to/agentic-workflow-orchestrator/scripts/setup-agents.sh /path/to/electrahub-repo
```

The setup script installs:

- `.github/agents/agent-rules.md`
- `.github/agents/eh-*.agent.md`
- `skills/SKILL.md`
- `skills/agents/eh-*/SKILL.md`
- `skills/references/workflow-menu.md`
- `docs/agent-commands.yml`
- `.ai/project-context.md`

The script also cleans old generated agent names, including prior phase-abbreviation agents and older `electrahub-*` generated files, so the target repository does not keep stale agents in `.github/agents`.

## Configure Repository Commands

After installation, edit the generated file in the target repository:

```text
docs/agent-commands.yml
```

This file is the command contract used by the agents. It should include exact ElectraHub commands for the repository, such as build, test, lint, service validation, and Kubernetes checks. Agents should use this file instead of guessing commands.

## Recommended First Run

From the target ElectraHub repository, start with `01-launchpad` and provide the requirement in chat:

```text
@01-launchpad implement connector tariff preview in station management
```

Then follow the next-agent recommendation written in `/agentWork/<WORK_ID>/`.

## External Tracking Behavior

External issue tracker integrations are not required or configured by this orchestrator.

- Requirements are captured directly from chat.
- Work ids are generated as `REQ-<YYYYMMDD>-<slug>`.
- External ticket ids, if pasted by the user, are stored as plain context only.
- Core workflow agents do not fetch, create, or update external issue tracker records.

## ElectraHub Domain Checks

Agents are expected to call out impacts across relevant ElectraHub areas:

- OCPP charger communication and connector state
- OCPI roaming behavior
- charging sessions and meter values
- tariff, pricing, billing, payments, and CDRs
- station management and admin UI behavior
- driver portal or mobile-facing behavior
- tenant, RBAC, and authorization boundaries
- eventing, idempotency, retries, and failure recovery
- Kubernetes resources, deployment config, and runtime capacity
- Splunk/Grafana observability, trace correlation, and log-level correctness
- TeamCity/JMeter regression evidence and load-test failure classification

## Operations And Incident Workflows

Use `93-observability-sentinel` for Splunk exports, Splunk URLs, trace ids, Grafana symptoms, Kubernetes warning floods, or production incidents.

Use `41-regression-sentinel` for TeamCity regression runs, JMeter failures, charging-flow validation, SSE/OCPP meter-value checks, CDR generation, and dashboard analytics verification.

Shared operational references live in `skills/references/`:

- `electrahub-service-catalog.md`
- `current-platform-state.md`
- `observability-playbook.md`
- `regression-playbook.md`
- `logging-standard.md`
