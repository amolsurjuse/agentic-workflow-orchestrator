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

## Policy migration

User-service Liquibase change `0025-deny-readonly-admin-user-data` removes the previous read-only ALLOW rules and installs explicit DENY rules for root and nested user-directory paths. Updating the gateway policy version causes gateway instances to refresh the database-backed policy.

## Validation

- Admin portal TypeScript and Vite production build.
- Gateway authorization test covers customer/admin list and detail paths for both roles.
- User-service tests assert search and count reject `ADMIN_READ_ONLY` before repository access.
- Full gateway and user-service test suites.
- Production browser validation with read-only and system-admin sessions after deployment.

## Acceptance criteria

- [x] Read-only navigation contains no Manage Users group.
- [x] Direct user-management URLs show `Not authorized` without loading user data.
- [x] Gateway returns forbidden for read-only user-directory requests.
- [x] User-service rejects read-only directory access before database access.
- [x] System-admin user-management access is unchanged.
- [ ] Production deployment completed.
- [ ] Production role-based browser and API validation completed.
