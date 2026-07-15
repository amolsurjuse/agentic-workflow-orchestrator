# Read-only admin user privacy

## Requirement

Accounts with the `ADMIN_READ_ONLY` role must not see or retrieve customer or administrator identity data. The restriction covers names, email addresses, phone numbers, addresses, and other user-profile fields. A direct visit to a user-management URL must show a clear `Not authorized` state.

`SYSTEM_ADMIN` keeps full user-management access. Regular driver accounts keep their existing self-service profile behavior.

## Threat model

Hiding a navigation item is not an authorization control. A read-only account could otherwise call the user APIs directly, retain a bookmarked route, or use a stale frontend bundle. The control is therefore enforced at three independent boundaries:

| Boundary | Enforcement |
| --- | --- |
| Admin portal | Hide the complete Manage Users navigation group. Direct user-management routes render `Not authorized` and do not mount a user page or fetch user data. |
| API gateway | Explicit role-scoped `DENY` rules override the broad authenticated `USER` rule for customer and admin user-directory roots and descendants. |
| User service | Spring method authorization rejects admin-user reads, and the directory service rejects `ADMIN_READ_ONLY` before any repository query. |

Production validation also found driver names and email addresses in the dashboard leaderboard. Read-only users therefore retain aggregate revenue, session, energy, and utilization analytics, but the portal does not request or render driver leaderboards, per-driver session detail, or user-report downloads. Gateway DENY rules protect those billing analytics endpoints from direct access.

## Protected routes

| Route | Read-only admin | System admin |
| --- | --- | --- |
| `GET /user/api/v1/users` | `403 Forbidden` | Allowed |
| `/user/api/v1/users/**` | `403 Forbidden` | Allowed according to the existing user-service policy |
| `GET /user/api/v1/admin/users` | `403 Forbidden` | Allowed |
| `/user/api/v1/admin/users/**` | `403 Forbidden` | Allowed according to the existing admin policy |
| Admin portal `/users` | `Not authorized` page | User list |
| Admin portal `/admin-users` | `Not authorized` page | Admin user list |
| Admin portal `/rbac/policy` | `Not authorized` page | RBAC policy editor |
| `GET /billing/api/v1/admin/analytics/users` | `403 Forbidden` | Allowed |
| `/billing/api/v1/admin/analytics/users/**` | `403 Forbidden` | Allowed |
| `/billing/api/v1/admin/analytics/reports/**` | `403 Forbidden` | Allowed |
| Aggregate billing analytics | Allowed | Allowed |

## Policy migration

User-service Liquibase change `0025-deny-readonly-admin-user-data` removes the previous read-only ALLOW rules and installs explicit DENY rules for root and nested user-directory paths. Change `0026-deny-readonly-admin-driver-analytics` denies driver-identity analytics and user report endpoints while preserving aggregate analytics. Updating the gateway policy version causes gateway instances to refresh the database-backed policy.

## Validation

- Admin portal TypeScript and Vite production build.
- Gateway authorization test covers customer/admin list and detail paths for both roles.
- User-service tests assert search and count reject `ADMIN_READ_ONLY` before repository access.
- Full gateway and user-service test suites.
- Production browser validation with read-only and system-admin sessions after deployment.

## Acceptance criteria

- [x] Read-only navigation contains no Manage Users group.
- [x] Read-only profile shortcuts contain no user-management links.
- [x] Direct user-management URLs show `Not authorized` without loading user data.
- [x] Gateway returns forbidden for read-only user-directory requests.
- [x] Read-only dashboard does not request or render driver identity analytics.
- [x] Gateway denies read-only driver leaderboard, per-driver session, and user-report requests.
- [x] User-service rejects read-only directory access before database access.
- [x] System-admin user-management access is unchanged.
- [ ] Production deployment completed.
- [ ] Production role-based browser and API validation completed.
