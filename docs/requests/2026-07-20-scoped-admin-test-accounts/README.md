# Scoped administrator test accounts

## Request

Create production-ready demonstration administrator accounts for every supported access level so the hierarchy-scoped RBAC rollout can be verified from the Admin Portal.

## Assigned hierarchy

| Hierarchy level | Identifier | Display name |
| --- | --- | --- |
| Enterprise | `ENT-US-DEV` | ElectraHub Demo Enterprise |
| Network | `NW-EH-USA-DEMO` | ElectraHub USA Corridor |
| Location | `LOC-USA-001` | ElectraHub New York Site 001 |

## Provisioned access matrix

| Account purpose | Email | Role(s) | Explicit grant | Expected boundary |
| --- | --- | --- | --- | --- |
| System administrator | `system.admin.demo@electrahub.net` | `SYSTEM_ADMIN` | None | Can administer all platform data and provision operators. |
| Enterprise administrator | `enterprise.admin.demo@electrahub.net` | `ENTERPRISE` | `ENT-US-DEV` / `OPERATE` | Can operate only the Demo Enterprise and every descendant network, location, charger, connector, session, and aggregate. |
| Network administrator | `network.admin.demo@electrahub.net` | `NETWORK` | `NW-EH-USA-DEMO` / `OPERATE` | Can operate only the Demo USA Corridor and descendants; parent enterprise is read-only. |
| Location administrator | `location.admin.demo@electrahub.net` | `LOCATION` | `LOC-USA-001` / `OPERATE` | Can operate only the Demo New York location and its chargers/connectors; ancestors are read-only. |
| Read-only demonstration administrator | `readonly.admin.demo@electrahub.net` | `ADMIN_READ_ONLY`, `ENTERPRISE` | `ENT-US-DEV` / `READ` | Can review only the Demo Enterprise data. User/customer data and all mutations remain denied. |

## Security handling

- A distinct strong one-time password was generated for each account.
- Passwords are deliberately excluded from this repository and from operational logs; they were delivered only to the requesting administrator.
- Accounts are enabled and email-verified so no email-verification step blocks their first sign-in.
- The standard legal-terms flow remains in force. A new account must accept the applicable terms before it can call protected APIs; the platform must never accept legal terms on behalf of an operator.

## Verification

1. Confirmed all five users are persisted in `user_mgmt.users`, are enabled, and are email-verified.
2. Confirmed role assignments and grants exactly match the matrix above.
3. Authenticated every account through `POST /auth/api/auth/login`.
4. Confirmed the issued JWT role claims for each account.
5. Do not reuse these accounts as real operators. Change each temporary password before further use and remove the accounts once scope validation is complete.

