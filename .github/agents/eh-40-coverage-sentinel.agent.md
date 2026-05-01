---
description: "ElectraHub test coverage agent: identify service, client, protocol, and charging-domain coverage gaps."
name: 40-coverage-sentinel
argument-hint: Target module and coverage threshold
tools: [execute/getTerminalOutput, execute/runInTerminal, execute/runTests, read/readFile, search, agent, todo]
target: vscode
model: Claude Opus 4.6 (copilot)
---

# Coverage Sentinel

> Step 0: Read [@agent-rules.md](agent-rules.md).

## Output
Persist to `/agentWork/<WORK_ID>/40-coverage-sentinel.out.<RUN>.md`.
