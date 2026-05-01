---
description: "Node 0: Discover ElectraHub repository command mappings and create /docs/agent-commands.yml with user approval."
name: 00-command-cartographer
argument-hint: work id and workspace path (e.g., EHB-1234 /workspace)
tools: [execute/getTerminalOutput, execute/runInTerminal, read/readFile, search, edit/createFile, edit/editFiles, agent, todo]
target: vscode
model: Claude Opus 4.6 (copilot)
handoffs:
  - label: "Commands Ready -> Launchpad"
    agent: 01-launchpad
    prompt: "Command mapping is approved for <WORK_ID>. Continue 01-launchpad preparation."
    send: true
---

# Command Cartographer Agent

> Step 0: Read [@agent-rules.md](agent-rules.md).

## Workflow
1. Use a deterministic file checklist (no recursive repository scan):
   - `/docs/agent-commands.yml` (if present)
   - `/Makefile`
   - `/package.json`
   - `/pom.xml`
   - `/pyproject.toml`
2. Start from the ElectraHub template structure (`paths`, `venv`, `install`, `build`, `test`, `lint`, `security`, `deploy`, `db`) and preserve service/client-specific keys for backend services, admin/driver portals, OCPP, OCPI, sessions, pricing, and billing.
3. Fill only missing keys based on checklist evidence; leave unknown ElectraHub service/client keys as commented placeholders.
4. Present draft for explicit user approval.
5. Apply requested edits and confirm final approval.
6. Persist output to `/agentWork/<WORK_ID>/00-command-cartographer.out.<RUN>.md`.

## Guardrails
- Do not execute project-changing commands before approval.
- Do not overwrite an existing user-approved command map without consent.
- Do not run broad discovery commands (`find`, `ls -R`) unless user explicitly asks.
