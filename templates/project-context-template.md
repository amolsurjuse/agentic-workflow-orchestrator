# ElectraHub Project Context Template

Use this document to capture reusable ElectraHub repository intelligence for AI-assisted delivery across Java/Spring Boot services, admin/driver clients, mobile apps, OCPP charger integrations, OCPI roaming integrations, and Kubernetes-backed operations.

## 1. System Overview
- Project name: ElectraHub
- Business domain: EV charging platform for drivers, charge point operators, station administrators, and roaming partners.
- Primary users: drivers, fleet/admin users, operators/tenants, support users, roaming partners, charger devices.
- Critical end-to-end flows:
  - Driver discovers station/location, views connector availability and tariff, starts/stops session, pays, and receives charging history/CDR.
  - Charger connects over OCPP, reports status/meter values, accepts remote start/stop, and keeps connector state synchronized.
  - OCPI peer exchanges locations, EVSE/connector data, tariffs, sessions, CDRs, credentials, and commands.
  - Admin/operator configures locations, chargers, connectors, tariffs, users/RBAC, and operational settings.

## 2. Platform Inventory
### Backend Services
- Service list (confirm exact repo names): api-gateway, auth-service, user-service, station-management-service, charger-management-service, ocpp-service/web-socket-connector, ocpi-service, session-service, pricing-service, billing-service, payment-service, notification-service.
- Runtime stack: Java/Spring Boot, Maven, REST/GraphQL where applicable, database migrations, Kubernetes deployment.

### Web Clients
- Admin/operator portal purpose:
- Driver portal purpose:
- Angular apps and purpose:
- React apps and purpose:

### Mobile Clients
- iOS driver app(s) and purpose:
- Android app(s) and purpose (if any):

## 3. Protocol Inventory (Charging)
- OCPP scope in ElectraHub: charger connection management, BootNotification, Heartbeat, StatusNotification, Authorize, StartTransaction/StopTransaction, MeterValues, RemoteStartTransaction/RemoteStopTransaction, diagnostics/firmware where supported.
- OCPP versions supported (confirm exact): 1.6J, 2.0.1 if enabled.
- OCPI scope in ElectraHub: locations, EVSEs, connectors, tariffs, sessions, CDRs, credentials, tokens, commands, partner/hub integration.
- OCPI version target (confirm exact version):
- Internal protocol surfaces (REST, GraphQL, WebSocket, SSE, gRPC):

## 4. Charging Domain Model Map
- Location
- Station / Site
- Charger / Charge Point
- EVSE
- Connector
- Tariff / Price Plan
- Session
- CDR
- Driver/User
- Operator/Tenant
- RFID/Token
- Payment / Invoice
- Meter Value
- Status transitions and ownership semantics:
  - Connector states such as Available, Preparing, Charging, SuspendedEVSE, SuspendedEV, Finishing, Reserved, Unavailable, Faulted.
  - Session lifecycle from authorization through start, active charging, stop, billing, and CDR finalization.
  - Tenant/operator boundaries for station ownership, user access, tariffs, and reports.

## 5. Repository Layout
- Monorepo or multi-repo:
- Top-level modules/services:
- Shared libraries:
- Infrastructure folders:
- Configuration directories:

## 6. API / Contract Matrix
| Consumer | Interface | Endpoint / Topic / Channel | Owner Service | Auth Model |
|---|---|---|---|---|
| ElectraHub Admin Portal | REST/GraphQL |  |  |  |
| ElectraHub Driver Portal | REST/GraphQL/SSE |  |  |  |
| iOS Driver App | REST/GraphQL/SSE |  |  |  |
| Charger/OCPP Device | WebSocket |  |  |  |
| OCPI Peer / Hub | REST |  |  |  |

## 7. Architecture Notes
- Service boundaries:
- Dependency directions:
- Integration patterns:
- External dependencies:
- Critical domain invariants:
  - Connector status shown to drivers/admins must reflect authoritative charger/OCPP and session state.
  - Tariffs displayed before session start must align with billing/CDR outcomes.
  - OCPI payloads must remain backward compatible with connected peers.
  - Payment, invoice, and CDR records must be auditable and idempotent.
  - Tenant/operator data must not leak across boundaries.

## 8. Coding Conventions
- Package naming:
- DTO/entity/service naming:
- Logging standard:
- Exception handling standard:
- Validation style:
- JavaDoc expectations:

## 9. Build / Test Commands by Platform
### Java Services
- Compile: `mvn clean compile`
- Unit tests: `mvn test`
- Full validation: `mvn clean test && mvn verify`

### Angular
- Install: `npm install`
- Run: `npm run start`
- Build: `npm run build`
- Test: `npm run test`

### React (Vite)
- Install: `npm install`
- Run: `npm run dev`
- Build: `npm run build`
- Typecheck: `npm run typecheck`

### iOS
- Xcode project path:
- Build/typecheck command(s):
- Simulator/device constraints:

## 10. Story Change Impact Checklist
For each story, mark impacted areas:
- [ ] Java/Spring Boot backend service logic
- [ ] OCPP behavior
- [ ] OCPI contract/payload
- [ ] Pricing/tariff display or calculation
- [ ] Payment/billing/CDR generation
- [ ] Connector/session status behavior
- [ ] GraphQL schema/query changes
- [ ] Admin/operator portal flow
- [ ] Driver portal flow
- [ ] iOS flow
- [ ] DB schema/data migration
- [ ] Eventing/WebSocket/SSE behavior
- [ ] Security/RBAC/authz impact
- [ ] Tenant/operator data isolation
- [ ] Kubernetes/config/secrets impact

## 11. Quality / Security
- Sonar project/key:
- Sonar execution command:
- Static analysis tools:
- Security scanning tools:
- Sensitive logging restrictions: never log tokens, payment data, OCPI credentials, user PII, secrets, or raw authorization payloads.

## 12. Delivery Conventions
- Branch naming:
- Commit message format:
- Jira linking rules:
- PR template and reviewer expectations:

## 13. Known Constraints / Risks
- Legacy modules:
- Common failure points:
- Required approvals:
- Environment-specific caveats:
