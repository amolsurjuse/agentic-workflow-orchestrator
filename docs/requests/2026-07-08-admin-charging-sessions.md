# Admin charging sessions navigation

Date: 2026-07-08

## Request

Add left navigation in the admin portal to view all charging sessions, with active and completed sessions separated and filters for location, charger, driver, payment mode, and related operational fields.

## Implementation

- Added admin portal page `ChargingSessionsPage`.
- Added left navigation entry `Charging Sessions`.
- Added active/completed tabs.
- Added filters:
  - Search
  - Location
  - Charger
  - Connector
  - Driver ID
  - Driver account
  - Driver type
  - Payment mode
  - Auth method
- Added admin session API client against `/session/api/v1/sessions/admin/search`.
- Added session-service admin search endpoint with pageable server-side filtering.
- Added gateway RBAC allow rule for `SYSTEM_ADMIN` and `ADMIN_READ_ONLY`.
- Added user-service Liquibase migration to sync the same gateway RBAC rule into the database-backed policy.

## Validation

- Admin portal production build passed.
- Session-service Maven tests passed in Docker.
- API gateway Maven tests passed in Docker.
- User-service Maven tests passed in Docker.

