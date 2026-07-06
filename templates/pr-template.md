# ElectraHub Pull Request Template (AI Delivery)

## Title
`[WORK_ID] <short technical summary>`

## Work Reference
- Work ID:
- Requirement source: chat
- Requirement summary:

## Branching
- Base branch: `develop` (unless explicitly overridden)

## Business Summary
- What ElectraHub outcome this PR delivers:
- Affected user/device/partner surface (driver, admin/operator, support, charger/OCPP, OCPI peer):

## Technical Summary
- Services/modules updated:
- Contracts/APIs changed:
- Data/config changes:
- Kubernetes/config/secrets impact:

## Protocol Impact Summary
- OCPP impact:
- OCPI impact:
- Internal protocol changes (REST/GraphQL/WebSocket/SSE/gRPC):

## Client Impact Summary
- Admin/operator portal impact:
- Driver portal impact:
- iOS driver app impact:
- Android driver app impact:
- Partner/OCPI API impact:
- Charger/OCPP integration impact:

## Charging Domain Impact Summary
- Connector/session status impact:
- Pricing/tariff impact:
- Payment/billing/CDR impact:
- Tenant/RBAC impact:

## Files / Components Impacted
-

## Implementation Notes
- Design choices made:
- Assumptions applied:
- Alternatives considered (if relevant):

## Testing Evidence
### Automated
- Unit tests:
- Integration tests:
- Build validation:

### Protocol Validation
- OCPP scenario(s):
- OCPI scenario(s):
- REST/GraphQL/WebSocket/SSE scenario(s):

### Client Validation
- Admin/operator portal scenario(s):
- Driver portal scenario(s):
- iOS driver app scenario(s):
- Android driver app scenario(s):

### Charging Domain Validation
- Connector/session scenario(s):
- Tariff/payment/CDR scenario(s):
- Tenant/RBAC scenario(s):

## Quality / Security Checks
- JavaDoc for new classes/methods: Yes/No
- Sonar/static analysis notes:
- Security checks and sensitive logging review (tokens, payment data, OCPI credentials, user PII, secrets):

## K8 Configuration Governance (When Backend Config Keys Change)
- K8 impact decision: `K8_CHANGE_REQUIRED | K8_NO_CHANGE_REQUIRED | K8_CHANGE_BLOCKED`
- Keys added/changed:
- Placement mapping (`config.data` / `env` / `secrets.env` / `extraSecretEnv`):
- `k8s-platform` files updated:
- Alignment check command and output summary:
