# Workflow Menu Prompts

## Start Feature Flow

```text
Run feature workflow for <JIRA_KEY>.
Start at f1.workspace-prep and follow the standard handoff chain.
Use token-saver mode: fixed root path from /docs/agent-commands.yml paths.root and no broad repo scans.
```

## Quick Agent Targets

1. `f0.repo-commands` — create/approve `/docs/agent-commands.yml`
2. `f1.workspace-prep` — workspace + branch readiness
3. `f2.intake` — requirement intake and acceptance criteria
4. `f3.repo-understanding` — impacted modules and dependencies
5. `f4.planner` — implementation plan and gate packet
6. `f5.implementer` — code implementation
7. `f6.validator` — test/validation execution
8. `f7.code-reviewer` — review findings
9. `f8.quality-implementer` — apply quality improvements
10. `f9.documentarian` — PR notes/docs
11. `f10.shipper` — ship/merge workflow
