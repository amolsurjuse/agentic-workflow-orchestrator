# Agentic Workflow Orchestrator

A screenshot-aligned multi-agent workflow for Jira-driven delivery with feature (`f*`) core flow plus architecture/refactor/test/meta utility agents.

## Feature Flow

```text
f1.workspace-prep
  -> f2.intake
  -> f3.repo-understanding
  -> f4.planner
  -> f5.implementer
  -> f6.validator
  -> f7.code-reviewer
  -> f8.quality-implementer
  -> f9.documentarian
  -> f10.shipper
  -> (optional) f10a.merge-resolver
```

## Utility/Domain Agents

- `f0.repo-commands` — builds `/docs/agent-commands.yml` with user approval
- `j.jira-creator` — Jira create/update helper
- `a1.c4-diagram-generator` — architecture diagram support
- `r1.quality-analyzer`, `r2.refactor-planner` — refactor flow
- `t1.coverage-analyzer` — test coverage flow
- `m1.agent-update-planner`, `m2.agent-updater`, `m3.k8s-resource-advisor` — meta tooling flow

## Repository Structure

```text
agentic-workflow-orchestrator/
├── .github/agents/
│   ├── agent-rules.md
│   ├── a1.c4-diagram-generator.agent.md
│   ├── f0.repo-commands.agent.md
│   ├── f1.workspace-prep.agent.md
│   ├── f2.intake.agent.md
│   ├── f3.repo-understanding.agent.md
│   ├── f4.planner.agent.md
│   ├── f5.implementer.agent.md
│   ├── f6.validator.agent.md
│   ├── f7.code-reviewer.agent.md
│   ├── f8.quality-implementer.agent.md
│   ├── f9.documentarian.agent.md
│   ├── f10.shipper.agent.md
│   ├── f10a.merge-resolver.agent.md
│   ├── j.jira-creator.agent.md
│   ├── m1.agent-update-planner.agent.md
│   ├── m2.agent-updater.agent.md
│   ├── m3.k8s-resource-advisor.agent.md
│   ├── r1.quality-analyzer.agent.md
│   ├── r2.refactor-planner.agent.md
│   └── t1.coverage-analyzer.agent.md
├── templates/
│   ├── agent-commands.yml
│   ├── jira-template.md
│   ├── pr-template.md
│   └── project-context-template.md
├── scripts/
│   └── setup-agents.sh
└── README.md
```

## Setup

1. Run setup from target repo root:

```bash
bash /path/to/agentic-workflow-orchestrator/scripts/setup-agents.sh
```

The setup script removes legacy `00..11-*` orchestrator artifacts before installing the current `f*`/utility agent set.

2. Edit `/docs/agent-commands.yml` for your project.
3. Start with `@f1.workspace-prep <JIRA_KEY> <short description>`.

For direct Jira fetch (example `KAN-3`), use:
`@j.jira-creator pull KAN-3`

Jira pull/read paths are non-terminal flows: agents should call Jira MCP directly and skip terminal readiness checks.
`f1.workspace-prep` can continue with a user-provided description when Jira MCP lookup fails.
When Jira tools are discovered but issue retrieval fails, agents should report Jira MCP request failure (not "tools unavailable").

## Notes

- All agents must read `agent-rules.md` first.
- Outputs are persisted under `/agentWork/<JIRA_KEY>/`.
- Command execution must use mappings from `/docs/agent-commands.yml`.
- Token-saver mode uses fixed path keys from `paths.*` in `/docs/agent-commands.yml` and avoids broad repository scans.
- Setup now ensures a `paths` block exists in `docs/agent-commands.yml` even when that file already exists.
- Jira tools are discovered dynamically in-session; namespace IDs for `*-jira-mcp-server/*` may differ by workspace.
