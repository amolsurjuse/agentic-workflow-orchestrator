# Jira Story Template (AI Delivery)

## Title
`[Service/Module] <clear business change>`

## Story ID
- Jira Key:

## Business Context
- Problem statement:
- Why this change is needed now:
- Target users and impact:

## Scope
### In Scope
- 

### Out of Scope
- 

## Functional Requirements
1. 
2. 
3. 

## Protocol and Platform Impact
### Protocols
- OCPP impact (Yes/No + details):
- OCPI impact (Yes/No + details):
- Other protocol/channel impact (REST/GraphQL/WebSocket/SSE/gRPC):

### Clients
- Angular impact:
- React impact:
- iOS impact:

## Technical Notes
- Impacted services/modules:
- Impacted APIs/contracts:
- Data model/config changes:
- Backward compatibility considerations:

## Assumptions
- 

## Dependencies
- Internal dependencies:
- External dependencies:

## Risks
- 

## Acceptance Criteria (Given / When / Then) — MANDATORY

> **This section is REQUIRED. A story cannot be created, approved, or handed off without validated acceptance criteria.**
> Minimum: 3 (Small), 5 (Medium), 8 (Large/XL). Every functional requirement must have at least one AC.

### Happy Path
AC-1: <Short descriptive title>
  Given <precondition / initial state>
  When  <action / trigger>
  Then  <expected outcome / observable result>
  Verification: <unit test / integration test / manual QA>
  Priority: MUST

AC-2: <Short descriptive title>
  Given ...
  When  ...
  Then  ...
  Verification: ...
  Priority: MUST

### Input Validation / Edge Cases
AC-3: <Short descriptive title — e.g., missing input, empty state, boundary>
  Given ...
  When  ...
  Then  ...
  Verification: ...
  Priority: MUST

### Error / Negative Scenarios
AC-4: <Short descriptive title — e.g., service failure, timeout, unauthorized>
  Given ...
  When  ...
  Then  ...
  Verification: ...
  Priority: MUST

### Additional Criteria (add as needed)
AC-5: ...

### Acceptance Criteria Summary
| # | Title | Category | Priority | Functional Req # |
|---|-------|----------|----------|-----------------|
| AC-1 | | Happy Path | MUST | FR-1 |
| AC-2 | | Happy Path | MUST | FR-2 |
| AC-3 | | Edge Case | MUST | FR-1 |
| AC-4 | | Error | MUST | FR-3 |

## Validation Plan (linked to Acceptance Criteria)
- Unit tests to add/update:
- Integration tests to run:
- Protocol compliance checks (OCPP/OCPI where relevant):
- Cross-client checks (Angular/React/iOS where relevant):
- Build commands:
  - `mvn clean test`
  - `mvn verify`

## Observability / Logging Notes
- New logs expected:
- Metrics/tracing impact:

## Rollout / Rollback
- Rollout approach:
- Rollback approach:

## Definition of Done
- [ ] Acceptance criteria validated (count, coverage, negative scenarios, format)
- [ ] Plan approved
- [ ] Implementation completed in approved scope
- [ ] Unit tests updated and passing
- [ ] JavaDoc added for new classes/methods
- [ ] Quality/security checks completed
- [ ] Build/verify passed
- [ ] OCPP/OCPI behavior validated (if in scope)
- [ ] Angular/React/iOS impact validated (if in scope)
- [ ] PR raised with evidence
