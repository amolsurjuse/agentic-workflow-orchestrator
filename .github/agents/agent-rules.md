# Agent Common Rules

This file contains shared rules that apply to **ALL agents** in the workflow. Each agent MUST follow these rules.

**Reference this file**: Include `@agent-rules.md` in your context or read this file at the start of execution.

> ⚠️ **FOR AGENTS**: You were directed here by Step 0 of your workflow. Read this ENTIRE file now. Every numbered rule below applies to you unless the "Applies to" line explicitly excludes your agent type.

> 📁 **PATH CONVENTION**: All paths in agent files that begin with `/` (for example `/agentWork/...`, `/docs/agent-commands.yml`) are relative to the workspace root directory (top-level folder open in the editor). Always resolve paths from the workspace root.

---

## 0. Agent Identification (MANDATORY)

**Applies to**: All agents

As the very first action when you begin execution, print this banner before any diagnostics, searches, or tool checks:

```text
🤖 Agent: <your name: field from frontmatter>
📋 Description: <your description: field from frontmatter>
🕐 Started: <YYYY-MM-DDTHH:mm:ss UTC>
```

If you are a domain subagent invoked via domain routing, also include:

```text
↪️ Invoked by: <primary agent>
📁 Domain: <domain>
```

---

## 1. Pre-Check: Verify Workspace Prep (MANDATORY)

**Applies to**: All agents except `f1.workspace-prep`

### Scope
This pre-check applies to **Feature flow (`f*`) agents only**. Architecture (`a*`), Refactor (`r*`), Test Coverage (`t*`), and Meta (`m*`) agents invoked directly by the user may proceed without workspace-prep verification.

Before doing ANY other work, read the latest `/agentWork/<JIRA_KEY>/f1.workspace-prep.out.*.md` and verify:
- The JIRA key in the handoff matches the workspace-prep output
- Workspace status shows `✅ Workspace is ready for feature work`

**If verification fails:**
1. **STOP IMMEDIATELY** — do not proceed
2. **Do NOT create `f1.workspace-prep.out.*.md` yourself** — only `f1.workspace-prep` can do this
3. **Do NOT fake or simulate workspace prep**
4. **Hand off to `f1.workspace-prep`** or inform the user to run it first

---

## 2. Command Reference (REQUIRED)

**Applies to**: All agents that run terminal commands

Before running ANY terminal commands, read `/docs/agent-commands.yml` to find the correct commands for this project.

- **If file exists**: Use the commands defined there
- **If file NOT found**:
  - For `f1.workspace-prep`: Run `f0.repo-commands` subagent to create it
  - For other agents: Ask the user: `I couldn't find /docs/agent-commands.yml. What commands should I use?`

When `f0.repo-commands` is used, it must:
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
   - `/agentWork/<JIRA_KEY>/`
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

**Behavioral rules:**
- For Jira pull/read requests, do NOT run terminal readiness checks — Jira MCP does not use the terminal.
- If MCP tools are discovered but a call fails, report the failure as a Jira MCP request error (auth/permission/network), not "tools unavailable."
- Jira-capable agents must include Jira tool names in `tools:` allowlists (function names and/or prefixed variants), otherwise Jira MCP appears unavailable.
- Do not suggest "enable terminal tools" when Jira MCP is the required path.
- `f1.workspace-prep` fallback: if Jira MCP is unavailable/fails, ask user for a brief description and continue (do not hard-stop).
- For Jira-only utility actions (`j.jira-creator pull KAN-3`): if MCP is not connected, emit Rule 5 hard-stop only.
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
`/agentWork/<JIRA_KEY>/<agentName>.out.<RUN>.md`

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

⚠️ This is a HARD STOP rule.

If you encounter any environment issue, you MUST:
1. STOP immediately
2. Do NOT attempt workarounds
3. Escalate to user with:
   `⚠️ Environment issue encountered: [describe issue]. Please resolve and re-run.`

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
- `/agentWork/<JIRA_KEY>/f1.workspace-prep.out.*.md`
- `/agentWork/<JIRA_KEY>/f2.intake.out.*.md`
- `/agentWork/<JIRA_KEY>/f3.repo-understanding.out.*.md`
- `/agentWork/<JIRA_KEY>/f4.planner.out.*.md`
- `/agentWork/<JIRA_KEY>/f5.implementer.out.*.md`
- `/agentWork/<JIRA_KEY>/f6.validator.out.*.md`
- `/agentWork/<JIRA_KEY>/f7.code-reviewer.out.*.md`
- `/agentWork/<JIRA_KEY>/f8.quality-implementer.out.*.md`
- `/agentWork/<JIRA_KEY>/f9.documentarian.out.*.md`
- `/agentWork/<JIRA_KEY>/f10.shipper.out.*.md`

Always read the latest run number.

---

## 7. Naming Conventions

### File Names
Format: `<flowTypeAbbr><nodeId>.<function>.agent.md`

| Abbr | Flow Type | Example |
|------|-----------|---------|
| `a` | Architecture | `a1.c4-diagram-generator.agent.md` |
| `f` | Feature | `f1.workspace-prep.agent.md` |
| `r` | Refactor | `r1.quality-analyzer.agent.md` |
| `t` | Test Coverage | `t1.coverage-analyzer.agent.md` |
| `m` | Meta | `m1.agent-update-planner.agent.md` |

### Output Files
Format: `<agentName>.out.<run>.md`
- Example: `f1.workspace-prep.out.1.md`

### Branch Names
Format: `feature/<JIRA-KEY>-<kebab-case-description>`
- Example: `feature/EHB-1234-add-analytics-api`

---

## 8. Routing and Handoffs

**Applies to**: Agents with handoffs

- Use frontmatter handoff definitions to route next
- Replace `<JIRA_KEY>` placeholders with actual key
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
| 1 | Verify workspace prep output |
| 2 | Read `/docs/agent-commands.yml` first |
| 3 | Validate terminal readiness |
| 4 | Persist output with run metadata |
| 5 | STOP and escalate environment issues |
| 6 | Read prior agent outputs |
| 7 | Use naming conventions |
| 8 | Route using handoffs |
| 9 | Follow implementation principles |
