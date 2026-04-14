# Pull Request Template (AI Delivery)

## Title
`[JIRA-KEY] <short technical summary>`

## Jira Reference
- Story/Ticket:
- Requirement link:

## Branching
- Base branch: `develop` (unless explicitly overridden)

## Business Summary
- What user/business outcome this PR delivers:

## Technical Summary
- Services/modules updated:
- Contracts/APIs changed:
- Data/config changes:

## Protocol Impact Summary
- OCPP impact:
- OCPI impact:
- Internal protocol changes (REST/GraphQL/WebSocket/SSE/gRPC):

## Client Impact Summary
- Angular impact:
- React impact:
- iOS impact:

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

### Client Validation
- Angular scenario(s):
- React scenario(s):
- iOS scenario(s):

## Quality / Security Checks
- JavaDoc for new classes/methods: Yes/No
- Sonar/static analysis notes:
- Security checks and sensitive logging review:

## K8 Configuration Governance (When Backend Config Keys Change)
- K8 impact decision: `K8_CHANGE_REQUIRED | K8_NO_CHANGE_REQUIRED | K8_CHANGE_BLOCKED`
- Keys added/changed:
- Placement mapping (`config.data` / `env` / `secrets.env` / `extraSecretEnv`):
- `k8s-platform` files updated:
- Alignment check command and output summary:

## Backward Compatibility
- Compatibility impact:
- Consumer impact:

## Risks and Mitigations
- 

## Rollout Plan
- 

## Rollback Plan
- 

## Reviewer Checklist
- [ ] Scope matches approved plan
- [ ] Acceptance criteria satisfied
- [ ] Tests are adequate and passing
- [ ] OCPP/OCPI impact reviewed where applicable
- [ ] Angular/React/iOS impact reviewed where applicable
- [ ] K8 config governance evidence included when backend config keys changed
- [ ] No unrelated changes included
- [ ] Risk notes and rollout guidance are clear
