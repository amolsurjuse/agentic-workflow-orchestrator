# ElectraHub Jira Story Template (AI Delivery)

## Title
`[ElectraHub <service/client/protocol>] <clear charging-domain business change>`

## Story ID
- Jira Key:

## Business Context
- Problem statement:
- Why this change is needed now:
- Target ElectraHub users and impact (driver/admin/operator/partner/support/charger device):

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
- Admin/operator portal impact:
- Driver portal impact:
- iOS driver app impact:
- Partner/OCPI API impact:
- Charger/OCPP integration impact:

## Technical Notes
- Impacted ElectraHub services/modules:
- Impacted APIs/contracts:
- Data model/config changes:
- Backward compatibility considerations:
- Kubernetes/config/secrets impact:

## Assumptions
- 

## Dependencies
- Internal dependencies (for example pricing, billing, session, charger, ocpi, user/auth):
- External dependencies (payment provider, OCPI peer/hub, charger firmware/network):

## Risks
- Protocol compatibility:
- Connector/session state consistency:
- Tariff/payment/CDR correctness:
- Tenant/RBAC data exposure:

## Acceptance Criteria (Given / When / Then) — MANDATORY

> **This section is REQUIRED. A story cannot be created, approved, or handed off without validated acceptance criteria.**
> Minimum: 3 (Small), 5 (Medium), 8 (Large/XL). Every functional requirement must have at least one AC.

### Happy Path
AC-1: <Short ElectraHub scenario title>
  Given <ElectraHub precondition / initial state, such as connector status, tariff, user role, or OCPI peer state>
  When  <driver/admin/operator/partner/charger action or system trigger>
  Then  <observable ElectraHub outcome, API response, UI state, OCPP/OCPI payload, or persisted record>
  Verification: <unit test / integration test / manual QA>
  Priority: MUST

AC-2: <Short descriptive title>
  Given ...
  When  ...
  Then  ...
  Verification: ...
  Priority: MUST

### Input Validation / Edge Cases
AC-3: <Short descriptive title, for example missing connector, stale charger status, invalid tariff, empty station list>
  Given ...
  When  ...
  Then  ...
  Verification: ...
  Priority: MUST

### Error / Negative Scenarios
AC-4: <Short descriptive title, for example pricing-service 404, OCPP timeout, OCPI peer rejection, unauthorized tenant access>
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
- Integration tests to run (service-to-service, DB, OCPI/OCPP where applicable):
- Protocol compliance checks (OCPP/OCPI where relevant):
- Cross-client checks (admin portal/driver portal/iOS where relevant):
- Build commands:
  - `mvn clean test`
  - `mvn verify`

## Observability / Logging Notes
- New logs expected:
- Metrics/tracing impact:
- Sensitive fields to avoid logging (tokens, payment data, OCPI credentials, user PII, secrets):

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
- [ ] Tariff/payment/CDR correctness validated (if in scope)
- [ ] Admin/driver/iOS impact validated (if in scope)
- [ ] Tenant/RBAC boundaries validated (if in scope)
- [ ] Kubernetes/config/secrets impact reviewed (if in scope)
- [ ] PR raised with evidence
