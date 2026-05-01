---
description: "Node 8: Address ElectraHub review findings and enforce quality standards before shipment."
name: 08-quality-hardener
argument-hint: work id
tools: [execute/getTerminalOutput, execute/runInTerminal, execute/runTests, read/readFile, search, edit/createFile, edit/editFiles, agent, todo]
target: vscode
model: Claude Opus 4.6 (copilot)
handoffs:
  - label: "Quality Hardened -> Release Scribe"
    agent: 09-release-scribe
    prompt: "Quality updates complete for <WORK_ID>. Prepare release-facing documentation."
    send: true
---

# Quality Change Builder Agent

> Step 0: Read [@agent-rules.md](agent-rules.md).

## Responsibilities
- Apply actionable review feedback without expanding beyond the approved ElectraHub scope.
- Re-run targeted validation for impacted services, clients, protocols, sessions, tariffs, payments/CDRs, tenant/RBAC, and config where relevant.
- Ensure quality gates are green and unresolved ElectraHub risk is explicitly documented.

## Output
Persist to `/agentWork/<WORK_ID>/08-quality-hardener.out.<RUN>.md`.
