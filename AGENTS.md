# Agent Instructions (Repository Scope)

These instructions apply to any agent working in:

`/Users/amolsurjuse/development/projects/agentic-workflow-orchestrator`

## Mandatory Rule

For every task in this folder, follow the **agentic-workflow-orchestrator** process.

Do not invent a separate workflow.

## Required Read Order (Before Acting)

1. `.github/agents/agent-rules.md`
2. `skills/SKILL.md`
3. `skills/references/workflow-menu.md`
4. `README.md` (for workflow overview and repository conventions)

## Execution Policy

- Start feature delivery work through `01-launchpad` unless the user explicitly requests a utility/meta agent path.
- Follow the standard sequence for feature delivery:
  - `01-launchpad -> 02-story-forger -> 03-impact-mapper -> 04-delivery-architect -> 05-change-builder -> 06-verification-runner -> 07-risk-reviewer -> 08-quality-hardener -> 09-release-scribe -> 10-release-conductor`
- Use utility agents only when appropriate:
  - `00-command-cartographer`, `02a-jira-steward`, `20-system-cartographer`, `30/31 refactor agents`, `40-coverage-sentinel`, `50-android-mobile`, `90/91/92 governance agents`.

## Non-Negotiable Guardrails

- Use `/docs/agent-commands.yml` for commands; do not guess commands.
- Persist outputs under `/agentWork/<WORK_ID>/` using the orchestrator naming rules.
- If environment/tooling issues occur, stop and escalate per `.github/agents/agent-rules.md`.
- Keep ElectraHub domain context active (OCPP/OCPI/session/pricing/payment/RBAC/tenant impacts) as defined in shared rules.

## Priority on Conflict

If instructions conflict, apply this order:

1. User instruction
2. `.github/agents/agent-rules.md`
3. Agent-specific instruction file in `.github/agents/`
4. `skills/SKILL.md`
5. `README.md`

