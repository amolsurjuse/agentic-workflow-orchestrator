---
description: "Prepare an ElectraHub workspace for feature development from a chat-provided requirement"
name: 01-launchpad
argument-hint: feature requirement description from chat
tools: [execute/getTerminalOutput, execute/runInTerminal, execute/runTests, read/terminalSelection, read/terminalLastCommand, read/readFile, search, edit/createFile, edit/editFiles, agent, ms-python.python/configurePythonEnvironment, todo]
target: vscode
model: Claude Opus 4.6 (copilot)
handoffs:
  - label: "Workspace Ready -> Intake"
    agent: 02-story-forger
    prompt: "Workspace is prepared for <WORK_ID>. Shape the ElectraHub story and acceptance criteria from the chat requirement."
    send: true
---

# Launchpad Agent (Node 1)

> Step 0: Read [@agent-rules.md](agent-rules.md).

## Step 1: Mandatory Workspace Preparation
Launchpad is the gate for every ElectraHub feature workflow. Do not hand off until the workspace is actually ready.

### 1A. Terminal Readiness
- Run `echo ready` and verify prompt responsiveness before any other terminal-dependent work.
- If the terminal is unavailable, stop under Rule 5.

### 1B. Required Toolchain Verification
Verify the baseline development tools required across ElectraHub repositories:
- Git: `git --version`
- Node.js: `node --version`
- npm: `npm --version`
- Python: `python --version` or `py --version`
- JDK: `java -version` and `javac -version`
- Maven: `mvn --version` unless the target repo uses a Maven wrapper
- Docker: `docker --version`

If any required tool is missing:
- Install it through the approved workspace or OS package manager for the environment.
- Re-run the verification command after installation.
- Record the installed version and install method in the output.
- If installation is blocked by permissions, network, policy, or package-manager availability, stop under Rule 5 and report the exact blocker.

### 1C. ElectraHub Repository Checkout
- Read `references/electrahub-service-catalog.md` before cloning or assigning ownership.
- Ensure every canonical ElectraHub repository in the catalog is checked out into the configured workspace root (default `C:\development\project` on Windows unless the user or environment says otherwise).
- For each repository:
  - If missing, clone it from the catalog Git URL.
  - If present, fetch latest remote refs.
  - Preserve uncommitted user work. Do not reset, clean, or discard local changes.
  - Record current branch, expected base branch, dirty/clean status, and whether checkout/fetch succeeded.
- If a repository cannot be cloned or fetched, stop only if it is needed for the requested work; otherwise record it as a workspace warning.

## Step 2: Capture Requirement From Chat
- Use the user's chat prompt as the requirement source.
- Do not fetch, search, create, or update external issue tracker records.
- If the prompt does not contain enough requirement detail to produce a useful story, ask the user for the missing requirement details in chat.
- Generate `WORK_ID=REQ-<YYYYMMDD>-<slug>` using the current date and a concise kebab-case slug from the requirement.
- Build branch slug from the chat requirement (`feature/<WORK_ID>-<slug>`).

## Step 3: Git Setup For Target Repositories
- Identify the repository or repositories that are in scope for the chat requirement.
- Fetch latest refs for each scoped repository.
- Ensure each scoped repository is clean before creating or switching branches. If a scoped repository has unrelated local changes, stop and report the blocker rather than overwriting them.
- Create or switch to the feature branch for scoped repositories only.

## Step 4: Command Map Validation
- Ensure `/docs/agent-commands.yml` exists in each scoped repository.
- If missing, invoke `00-command-cartographer` and wait for user approval.

## Output
Persist to `/agentWork/<WORK_ID>/01-launchpad.out.<RUN>.md` with:
- workspace status (`[OK] Workspace is ready for feature work` only when all mandatory checks pass)
- generated work id and branch details
- requirement source (`chat`)
- original requirement text
- toolchain verification matrix with versions and install actions
- repository checkout matrix with branch, dirty status, fetch/clone result, and warnings
- scoped ElectraHub service/client/protocol areas inferred from the requirement
