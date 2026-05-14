# ElectraHub Agentic Workflow Orchestrator

ElectraHub Agentic Workflow Orchestrator is a Codex/GitHub agent package for running a structured delivery workflow across ElectraHub applications. It installs a sequenced set of agents into a target ElectraHub repository and gives those agents shared rules, handoff files, command mappings, and templates so feature work can move from requirement capture through implementation, validation, review, hardening, documentation, and release.

The workflow is tailored for ElectraHub domains such as EV charging backend services, admin and driver clients, OCPP charger integrations, OCPI roaming integrations, station management, pricing, billing, sessions, connector status, payments, CDRs, RBAC, tenant behavior, and Kubernetes-backed operations.

## What This Repository Provides

- Sequenced ElectraHub delivery agents under `.github/agents/`.
- Matching Codex skill instructions under `skills/agents/`.
- Shared repo-wide references under `skills/references/`, including the ElectraHub logging standard.
- Shared rules that every agent must read before acting.
- A setup script that installs the agent package into a target ElectraHub repository.
- Project templates for command mappings, Jira story structure, pull request notes, and project context.
- Support for either Jira-key driven work or plain description-only requirements.

## Requirement Input Modes

The workflow can start from a Jira issue or from a plain requirement description.

```text
@01-launchpad EH-1234 add charger tariff preview
```

```text
@01-launchpad add charger tariff preview to the station management UI
```

When a Jira key is present, the agents use it as the workflow work id.

```text
WORK_ID=EH-1234
```

When no Jira key is present, `01-launchpad` creates a local requirement id from the date and description.

```text
WORK_ID=REQ-20260501-add-tariff-preview
```

All agent handoffs and outputs are written under:

```text
/agentWork/<WORK_ID>/
```

This lets ElectraHub work continue even when a Jira ticket has not been created yet. The `02a-jira-steward` agent can later create or update Jira from the local requirement record.

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

Each runtime agent name includes the workflow sequence id. Agent files use the `eh-` file prefix, while runtime names avoid the `electrahub-` prefix for cleaner invocation.

## Agents

| Sequence | Runtime agent | Purpose |
| --- | --- | --- |
| 00 | `00-command-cartographer` | Builds and maintains `/docs/agent-commands.yml` after user approval. |
| 01 | `01-launchpad` | Starts a workflow from Jira or description-only input and creates the first work packet. |
| 02 | `02-story-forger` | Converts the requirement into an implementation-ready story. |
| 02a | `02a-jira-steward` | Pulls, creates, or updates Jira issues when Jira integration is needed. |
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
| 90 | `90-agent-governor` | Maintains agent governance and workflow consistency. |
| 91 | `91-instruction-editor` | Updates agent instructions safely. |
| 92 | `92-k8s-capacity-advisor` | Reviews Kubernetes resource and capacity concerns. |

## Repository Structure

```text
agentic-workflow-orchestrator/
├── .github/
│   └── agents/
│       ├── agent-rules.md
│       ├── eh-00-command-cartographer.agent.md
│       ├── eh-01-launchpad.agent.md
│       ├── eh-02-story-forger.agent.md
│       ├── eh-02a-jira-steward.agent.md
│       ├── eh-03-impact-mapper.agent.md
│       ├── eh-04-delivery-architect.agent.md
│       ├── eh-05-change-builder.agent.md
│       ├── eh-06-verification-runner.agent.md
│       ├── eh-07-risk-reviewer.agent.md
│       ├── eh-08-quality-hardener.agent.md
│       ├── eh-09-release-scribe.agent.md
│       ├── eh-10-release-conductor.agent.md
│       ├── eh-10a-conflict-stabilizer.agent.md
│       ├── eh-20-system-cartographer.agent.md
│       ├── eh-30-refactor-scout.agent.md
│       ├── eh-31-refactor-designer.agent.md
│       ├── eh-40-coverage-sentinel.agent.md
│       ├── eh-90-agent-governor.agent.md
│       ├── eh-91-instruction-editor.agent.md
│       └── eh-92-k8s-capacity-advisor.agent.md
├── scripts/
│   └── setup-agents.sh
├── skills/
│   ├── SKILL.md
│   ├── agents/
│   └── references/
│       └── workflow-menu.md
├── templates/
│   ├── agent-commands.yml
│   ├── jira-template.md
│   ├── pr-template.md
│   └── project-context-template.md
└── README.md
```

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

This file is the command contract used by the agents. It should include exact ElectraHub commands for the repository, such as:

- build commands
- unit test commands
- integration test commands
- frontend test commands
- lint and formatting commands
- service-specific validation commands
- Kubernetes or deployment checks when relevant

Agents should use this file instead of guessing commands.

## Recommended First Run

From the target ElectraHub repository, start with `01-launchpad`.

With Jira:

```text
@01-launchpad EH-1234 implement connector tariff preview in station management
```

Without Jira:

```text
@01-launchpad implement connector tariff preview in station management
```

Then follow the next-agent recommendation written in `/agentWork/<WORK_ID>/`.

## Jira Behavior

Jira is optional at workflow start.

- If a Jira key is provided, agents use Jira as the requirement source.
- If only a description is provided, agents create a local `REQ-*` work id and continue.
- If Jira tools are available but issue retrieval fails, agents should report the Jira request failure clearly.
- If Jira lookup fails but the user provided a useful description, `01-launchpad` can continue from that description.
- `02a-jira-steward` can create or update a Jira issue later from the local work packet.

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

## Validation

For this repository, basic validation is:

```bash
bash -n scripts/setup-agents.sh
git diff --check
```

For a target ElectraHub repository, use the commands configured in:

```text
docs/agent-commands.yml
```

## Maintenance Notes

- Keep `.github/agents/` and `skills/agents/` aligned when adding, removing, or renaming agents.
- Keep shared references in `skills/references/` aligned with service standards such as logging and observability.
- Keep runtime agent names sequenced and concise.
- Keep file names using the `eh-` abbreviation.
- Keep `agent-rules.md` as the shared source of workflow behavior.
- Do not add generic social media or non-delivery artifacts to this repository.
- Re-run `setup-agents.sh` after changing agents, skills, templates, or workflow references.
