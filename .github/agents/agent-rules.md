# Agent Common Rules

This file contains shared rules that apply to **ALL agents** in the workflow. Each agent MUST follow these rules.

**Reference this file**: Include `.agent-rules.md` in your context or read this file at the start of execution.

> **FOR AGENTS**: You were directed here by Step 0 of your workflow. Read this ENTIRE file now. Every numbered rule below applies to you unless the "Applies to" line explicitly excludes your agent type.

> **PATH CONVENTION**: All paths in agent files that begin with `/` (for example `/agentWork/...`, `/docs/agent-commands.yml`) are relative to the workspace root directory (top-level folder open in the editor). Always resolve paths from the workspace root.

---

## ElectraHub Application Context (MANDATORY)

**Applies to**: All agents

This orchestrator is tuned for **ElectraHub**, an EV charging platform. Treat every feature, review, test plan, Jira story, and PR as part of ElectraHub unless the user explicitly says otherwise.

### Product/domain assumptions
- Domain: EV charging, charger operations, driver experience, partner roaming, billing, pricing, payments, and station administration.
- Core flows: driver onboarding, charger discovery, connector availability, session start/stop, live session telemetry, tariff display, payment capture, CDR generation, operator/admin workflows, and roaming interoperability.
- Protocols to consider whenever relevant: OCPP for charger/device communication, OCPI for roaming and partner integrations, REST/GraphQL for internal APIs, WebSocket/SSE for live status and telemetry.
- Key entities: Location, Station, Charger/Charge Point, EVSE, Connector, Tariff/Price Plan, Session, CDR, Driver/User, Operator/Tenant, RFID/token, Payment, Invoice, Meter Value, Status Notification.

### Expected technical landscape
- Backend work is typically Java/Spring Boot microservices with Maven, database migrations, DTO/entity/service layers, REST clients, config keys, and operational logging.
- Frontend work may touch Angular/React admin or driver portal flows.
- Mobile work may touch iOS driver app flows.
- Infrastructure work may touch Kubernetes manifests/config, secrets, service discovery, observability, and rollout safety.

### ElectraHub delivery rules
- Always state whether OCPP, OCPI, pricing/tariff, payment, session, connector status, RBAC, or tenant/operator boundaries are impacted.
- When a story touches charging behavior, include at least one concrete scenario using ElectraHub domain language, for example connector status transitions, remote start/stop, tariff lookup failure, CDR generation, or OCPI peer payload compatibility.
- For backend config changes, call out Kubernetes/config governance and secret handling.
- For user-facing changes, identify the affected ElectraHub client surface: admin portal, driver portal, iOS app, partner/OCPI API, or charger/OCPP integration.
- Do not leave generic placeholders such as "service/module" or "business outcome" unresolved when ElectraHub-specific names can be inferred from the Jira story or repository context.

## 0. Agent Identification (MANDATORY)

**Applies to**: All agents

As the very first action when you begin execution, print this banner before any diagnostics, searches, or tool checks:

```text
AGENT_NAME=<your name: field from frontmatter>
AGENT_DESCRIPTION=<your description: field from frontmatter>
AGENT_STARTED=<YYYY-MM-DDTHH:mm:ss UTC>
```

If you are a domain subagent invoked via domain routing, also include:

```text
AGENT_INVOKED_BY=<primary agent>
AGENT_DOMAIN=<domain>
```

---

## 1. Pre-Check: Verify Launchpad (MANDATORY)

**Applies to**: All agents except `01-launchpad`

### Scope
This pre-check applies to the ElectraHub feature delivery agents only. Architecture, refactor, coverage, regression, observability, and meta utility agents invoked directly by the user may proceed without 01-launchpad verification.

Before doing ANY other work, read the latest `/agentWork/<WORK_ID>/01-launchpad.out.*.md` and verify:
- The work id in the handoff matches the 01-launchpad output
- Workspace status shows `[OK] Workspace is ready for feature work`

**If verification fails:**
1. **STOP IMMEDIATELY** — do not proceed
2. **Do NOT create `01-launchpad.out.*.md` yourself** — only `01-launchpad` can do this
3. **Do NOT fake or simulate 01-launchpad preparation**
4. **Hand off to `01-launchpad`** or inform the user to run it first

### Work ID
Every run must have a `WORK_ID`.
- If the input contains a Jira key, use that exact key as `WORK_ID`.
- If the input contains only a requirement description, generate `WORK_ID` as `REQ-<YYYYMMDD>-<slug>` using the current date and a concise kebab-case slug from the description.
- Use `WORK_ID` consistently for `/agentWork/<WORK_ID>/...`, branch names, handoffs, and output headers.
- Never block the workflow only because a Jira key is missing when a usable requirement description is present.

---

## 2. Command Reference (REQUIRED)

**Applies to**: All agents that run terminal commands

Before running ANY terminal commands, read `/docs/agent-commands.yml` to find the correct commands for this project.

- **If file exists**: Use the commands defined there
- **If file NOT found**:
  - For `01-launchpad`: Run `00-command-cartographer` subagent to create it
  - For other agents: Ask the user: `I couldn't find /docs/agent-commands.yml. What commands should I use?`

When `00-command-cartographer` is used, it must:
1. Create proposed mappings in `/docs/agent-commands.yml`
2. Pause for user review/approval
3. Continue only after explicit user approval

**Command syntax**: `<section.key>` means look up that path in `/docs/agent-commands.yml`.
- Example: `<install.all>` -> look up `install.all` -> run mapped command
- Example: `<test.backend>` -> look up `test.backend` -> run mapped command
- Example: `<lint.all>` -> look up `lint.all` -> run mapped command

**Never guess commands** — always check the reference file first.

### Token-Saver Execution Profile (MANDATORY)

Use this fixed flow to reduce token usage and avoid repeated repo discovery:

1. Resolve root path once:
   - If `/docs/agent-commands.yml` contains `paths.root`, use it.
   - Otherwise use workspace root (`/` path convention in this ruleset).
2. Hardcoded terminal prologue (run once):
   - `cd <root>`
   - `echo ready`
3. Use only these canonical paths during flow:
   - `/.github/agents/`
   - `/docs/agent-commands.yml`
   - `/agentWork/<WORK_ID>/`
4. Keep one working directory per run:
   - Do not bounce between directories with repeated `cd`.
   - For file commands (`vim`, `cat`, `ls`, edits), use paths under the same root.
5. Avoid expensive repo discovery unless explicitly required:
   - Skip `pwd`, `git rev-parse --show-toplevel`, recursive `find`, `ls -R`.
   - Prefer targeted reads/searches on known files.
6. Reuse node outputs instead of re-scanning:
   - Node 2+ should consume `/agentWork/...` artifacts first.

### Jira operations via Atlassian MCP Server

Jira read/write actions use the Atlassian MCP server.

- Use function-name calls first (`getJiraIssue`, `searchJiraIssuesUsingJql`, etc.); prefixed variants are fallback only.
- Default `cloudId`: `3a404367-e930-4995-a7fe-b1876a7c9b76`.
- Call `getAccessibleAtlassianResources` only if default cloudId fails.
- Always pass `responseContentFormat: "markdown"` when reading issues.

**VS Code MCP setup**: The Atlassian MCP server must be registered in `.vscode/mcp.json` (NOT in `settings.json`):
```json
{
  "servers": {
    "atlassian": {
      "type": "http",
      "url": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
```
This file is installed automatically by `setup-agents.sh`. If Jira MCP is unavailable, verify `.vscode/mcp.json` exists in the project root and restart VS Code.

**Behavioral rules:**
- For Jira pull/read requests, do NOT run terminal readiness checks — Jira MCP does not use the terminal.
- If MCP tools are discovered but a call fails, report the failure as a Jira MCP request error (auth/permission/network), not "tools unavailable."
- Do not add MCP tool names (e.g. `atlassian/getJiraIssue`) to `tools:` frontmatter — MCP tools are discovered at runtime by function name only.
- Do not suggest "enable terminal tools" when Jira MCP is the required path.
- `01-launchpad` fallback: if Jira MCP is unavailable/fails, ask user for a brief description and continue (do not hard-stop).
- For Jira-only utility actions (`02a-jira-steward pull KAN-3`): if MCP is not connected, emit Rule 5 hard-stop only.
- Do not return fallback option menus for Jira pull requests.

---

## 3. Terminal Readiness Check

**Applies to**: All agents running terminal commands

Before executing any work commands:
1. Run `echo ready`
2. Confirm terminal responds with a prompt
3. If no response/error, retry after a short wait
4. Continue only after terminal readiness is confirmed

Jira-only requests that do not require terminal commands must skip terminal readiness.

Path standardization for terminal actions:
- Run `cd <root>` once, then keep all commands in that same root context.
- Do not run repeated `cd` chains.
- Use absolute workspace-relative paths for file actions.

### 3b. Activate virtual environment (if configured)
After terminal readiness, check `/docs/agent-commands.yml` for `venv.activate`.

- If `venv.activate` is defined: run it and verify activation succeeded
- If `venv.activate` is not defined: skip
- If activation fails: STOP and escalate under Rule 5

After activation, commands like `python`, `pip`, `pytest` should use the active environment.

---

## 4. Persist Output (REQUIRED)

**Applies to**: All agents

All agents MUST save output to:
`/agentWork/<WORK_ID>/<agentName>.out.<RUN>.md`

### Run Number Logic
- **Handoff from lower node**: Use same run number
- **Handoff from higher node (re-work cycle)**: Increment run number by 1
- **User re-run**: Find highest run number and increment by 1

### Timing
Record timing at start and end. Use terminal datetime command when terminal tools are available; otherwise record timestamps directly without terminal commands.

### Invocation Prompt
Capture the exact prompt used to invoke the agent:
- Handoff prompt from previous agent
- User prompt when directly invoked

### Output File Header Template
```text
Run: <RUN_NUMBER> | Start: <timestamp> | End: <timestamp> | Elapsed: <duration>
Invocation: "<exact invocation prompt>"
```

---

## 5. Environment Issues — STOP and Escalate (MANDATORY)

**Applies to**: All agents — **NO EXCEPTIONS**

This is a HARD STOP rule.

If you encounter any environment issue, you MUST:
1. STOP immediately
2. Do NOT attempt workarounds
3. Escalate to user with:
   `Environment issue encountered: [describe issue]. Please resolve and re-run.`

### What counts as an environment issue
- File read/write failures
- Tool failures/errors
- Missing required tools
- Terminal unresponsive
- Missing dependencies/configuration

### Prohibited workarounds
- Substituting missing tools with shell hacks
- Continuing with partial functionality
- Writing/reading files through alternative channels when required tools are unavailable
- Returning generic option menus instead of the required hard-stop escalation when tools are missing

---

## 6. Input Patterns

**Applies to**: All agents (Node 2+)

Read previous outputs to understand context:
- `/agentWork/<WORK_ID>/01-launchpad.out.*.md`
- `/agentWork/<WORK_ID>/02-story-forger.out.*.md`
- `/agentWork/<WORK_ID>/03-impact-mapper.out.*.md`
- `/agentWork/<WORK_ID>/04-delivery-architect.out.*.md`
- `/agentWork/<WORK_ID>/05-change-builder.out.*.md`
- `/agentWork/<WORK_ID>/06-verification-runner.out.*.md`
- `/agentWork/<WORK_ID>/07-risk-reviewer.out.*.md`
- `/agentWork/<WORK_ID>/08-quality-hardener.out.*.md`
- `/agentWork/<WORK_ID>/09-release-scribe.out.*.md`
- `/agentWork/<WORK_ID>/10-release-conductor.out.*.md`

Always read the latest run number.

---

## 7. Naming Conventions

### File Names
Format: `eh-<role>.agent.md`

| Abbr | Flow Type | Example |
|------|-----------|---------|
| `eh-arch` | Architecture | `eh-20-system-cartographer.agent.md` |
| `eh-flow` | Feature delivery | `eh-01-launchpad.agent.md` through `eh-10-release-conductor.agent.md` |
| `eh-refactor` | Refactor | `eh-30-refactor-scout.agent.md`, `eh-31-refactor-designer.agent.md` |
| `eh-test` | Test Coverage and Regression | `eh-40-coverage-sentinel.agent.md`, `eh-41-regression-sentinel.agent.md` |
| `eh-meta` | Meta and Operations | `eh-90-agent-governor.agent.md`, `eh-91-instruction-editor.agent.md`, `eh-92-k8s-capacity-advisor.agent.md`, `eh-93-observability-sentinel.agent.md` |

### Output Files
Format: `<agentName>.out.<run>.md`
- Example: `01-launchpad.out.1.md`

### Branch Names
Format: `feature/<WORK_ID>-<kebab-case-description>`
- Example with Jira: `feature/EHB-1234-add-analytics-api`
- Example without Jira: `feature/REQ-20260501-add-analytics-api`

---

## 8. Routing and Handoffs

**Applies to**: Agents with handoffs

- Use frontmatter handoff definitions to route next
- Replace `<WORK_ID>` placeholders with the actual work id
- Replace `<JIRA_KEY>` placeholders with the actual Jira key only when one exists; otherwise use `<WORK_ID>`
- Include relevant context in handoff prompt
- Route based on pass/fail outcomes

---

## 9. Principles

- **Smallest diff**: Only change what is necessary
- **Follow patterns**: Match existing conventions
- **No scope creep**: Avoid unrelated refactors
- **Guard imports**: Handle optional dependencies safely
- **Preserve contracts**: Avoid unexpected behavior changes

---

## 10. Agent Files in .gitignore

The `.github/agents/` directory should be in `.gitignore` in target repositories. These files are local tooling and should not be committed there.

---

## Quick Reference

| Rule | Key Action |
|------|------------|
| 0 | Print start identification banner |
| 1 | Verify 01-launchpad output |
| 2 | Read `/docs/agent-commands.yml` first |
| 3 | Validate terminal readiness |
| 4 | Persist output with run metadata |
| 5 | STOP and escalate environment issues |
| 6 | Read prior agent outputs |
| 7 | Use naming conventions |
| 8 | Route using handoffs |
| 9 | Follow implementation principles |
