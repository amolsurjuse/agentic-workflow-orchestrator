# Project Context Template

Use this document to capture reusable repository intelligence for AI-assisted delivery across backend services, web clients, and mobile clients.

## 1. System Overview
- Project name:
- Business domain:
- Primary users:
- Critical end-to-end flows:

## 2. Platform Inventory
### Backend Services
- Service list (auth, user, charger, ocpp, ocpi, session, pricing, payment, etc.):
- Runtime stack (Java/Spring Boot, etc.):

### Web Clients
- Angular apps and purpose:
- React apps and purpose:

### Mobile Clients
- iOS app(s) and purpose:
- Android app(s) and purpose (if any):

## 3. Protocol Inventory (Charging)
- OCPP scope in this platform (e.g., connection management, remote start/stop, telemetry):
- OCPP versions supported (e.g., 1.6J, 2.0.1):
- OCPI scope in this platform (e.g., locations, EVSE, sessions, CDR, tariffs):
- OCPI version target (confirm exact version):
- Internal protocol surfaces (REST, GraphQL, WebSocket, SSE, gRPC):

## 4. Charging Domain Model Map
- Location
- Charger / Charge Point
- EVSE
- Connector
- Tariff / Price Plan
- Session
- CDR
- Status transitions and ownership semantics

## 5. Repository Layout
- Monorepo or multi-repo:
- Top-level modules/services:
- Shared libraries:
- Infrastructure folders:
- Configuration directories:

## 6. API / Contract Matrix
| Consumer | Interface | Endpoint / Topic / Channel | Owner Service | Auth Model |
|---|---|---|---|---|
| Angular Driver Portal | REST/GraphQL |  |  |  |
| React Admin Portal | REST/GraphQL |  |  |  |
| iOS Driver App | REST/GraphQL/SSE |  |  |  |
| Charger/OCPP Device | WebSocket |  |  |  |
| OCPI Peer / Hub | REST |  |  |  |

## 7. Architecture Notes
- Service boundaries:
- Dependency directions:
- Integration patterns:
- External dependencies:
- Critical domain invariants:

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
- [ ] Backend service logic
- [ ] OCPP behavior
- [ ] OCPI contract/payload
- [ ] GraphQL schema/query changes
- [ ] Angular UI flow
- [ ] React admin flow
- [ ] iOS flow
- [ ] DB schema/data migration
- [ ] Eventing/WebSocket/SSE behavior
- [ ] Security/RBAC/authz impact

## 11. Quality / Security
- Sonar project/key:
- Sonar execution command:
- Static analysis tools:
- Security scanning tools:
- Sensitive logging restrictions:

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
