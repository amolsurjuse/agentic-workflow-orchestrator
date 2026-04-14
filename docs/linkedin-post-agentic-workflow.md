I built a multi-agent system that automates the entire SDLC — from a raw requirement to a production release — using 11 specialized AI agents and 3 human approval gates.

Here's the full agent chain:

```
Requirement --> [01 Requirements] --> [02 Analysis] --> [03 Planning]
                                                              |
                                                        GATE #1 (Plan Approval)
                                                              |
[04 Jira] --> [05 Implementation] --> [06 Testing] --> [07 Security] --> [08 Quality]
                                                                              |
                                                                        GATE #2 (PR Approval)
                                                                              |
                                            [09 PR] --> [10 Deployment] --> GATE #3 (Production)
                                                                              |
                                                                        [11 Release] --> Done
```

Here's what it covers:

Requirements intake and story creation with mandatory acceptance criteria (Given/When/Then, validated before handoff)

Technical analysis that detects DB migrations, API contract changes, and multi-repo scope automatically

Implementation planning with file-level change sets, deployment ordering, and estimation — paused at Gate #1 for human review

Code generation across feature branches, feature flags, and migration scripts

Testing pipeline: unit, integration, contract, E2E, and performance — all automated

Security scanning: dependency audit, SAST, secrets detection, RBAC review

Quality validation: JavaDoc, build verification, observability checks

PR creation with a structured review loop — paused at Gate #2

Deployment to staging with smoke tests and health checks — paused at Gate #3 before production promotion

Release closure: changelog, release notes, feature flag cleanup tracking, documentation updates, and Jira transition to Done

---

Three workflows I've been running through it:

WORKFLOW 1 — New Feature (Full Chain)

A real story: "Add pricing details to the iOS connector page and relocate the Start Charging button."

This touched 3 layers: backend (Spring Boot tariff resolution via billing-service), GraphQL schema (new OcpiTariff type), and iOS (SwiftUI ConnectorDetailView with pricing cards).

The workflow:
- Agent 01 captured the voice-transcribed requirement, generated 8 acceptance criteria covering happy path, missing tariff fallback, button visibility per status, and backward compatibility
- Agent 02 detected multi-repo scope (charger-management-service + driver-portal-ios), identified no DB migration needed, flagged a new REST dependency on billing-service
- Agent 03 produced a file-level plan with deployment ordering: backend first, then iOS
- Gate #1 approved
- Agent 05 created feature branches in both repos, added BillingTariffClient with ConcurrentHashMap caching, extended GraphQL schema, built the SwiftUI view
- Agents 06-08 validated tests, security, and quality
- Agent 09 drafted linked PRs with cross-repo references
- Gate #2 approved, PRs created

Total: requirement to PR-ready in a single session.

WORKFLOW 2 — Bug Fix (Compressed Chain)

Scenario: "Connector status shows 'Available' but billing service returns 404 for its tariff."

The workflow skips deep analysis and goes straight to planning:
- Agent 01 created a defect story with 5 ACs focused on error handling and fallback UI
- Agent 03 scoped the fix to 2 files: BillingTariffClient (catch 404, return empty Optional) and ConnectorDetailView (show "Pricing unavailable" fallback)
- Agent 05 created a defect/ branch, made the targeted fix
- Agent 06 ran unit tests with mock 404 responses
- Agent 09 created the PR
- Branch: defect/KAN-789-null-tariff-fix

WORKFLOW 3 — Hotfix (Fast-Track)

Scenario: "Production crash when connector has null tariffIds array."

The hotfix path compresses the chain:
- Agent 01 abbreviated intake (5 minutes, not 30)
- Agent 03 one-file plan, Gate #1 approved immediately
- Agent 05 null-safety guard in OcpiChargerGraphqlService
- Agent 06 unit test only (no integration/E2E)
- Agent 09 PR against main (not develop)
- Agent 10 direct to production after smoke test
- Branch: hotfix/KAN-999-session-crash

---

The key design decisions:

Each agent owns exactly one phase. No monolithic prompts trying to do everything. The Requirements Agent doesn't know how to deploy. The Deployment Agent doesn't write code. Single responsibility, clean handoffs.

Every agent communicates through a standardized context packet (inputs) and output packet (status, artifacts, exit criteria, next agent). This makes agents independently testable and replaceable.

Three approval gates keep humans in control at the critical decision points: plan approval, PR approval, and production promotion. The AI executes; the engineer decides.

Acceptance criteria are enforced as a hard gate — not optional. The system validates coverage, format, negative scenarios, and traceability to functional requirements before a story can proceed.

The whole system runs inside VS Code through Claude Code. Each agent is a SKILL.md file in a numbered folder. Adding a new agent means creating one markdown file and registering it in the orchestrator. No framework, no infrastructure — just structured prompts with clear contracts.

This isn't replacing engineers. It's giving them an execution layer that handles the mechanical parts of delivery while they focus on design decisions, code review, and production judgment calls.

What's next: exploring how this pattern scales across teams and whether the agent contracts can become a shared standard.

Check out the code and agent definitions on GitHub: https://github.com/amolsurjuse?tab=repositories

See the attached carousel for the visual workflow breakdown.

#SoftwareEngineering #AI #SDLC #DevOps #AgenticAI #ClaudeCode #Automation #EngineeringLeadership
