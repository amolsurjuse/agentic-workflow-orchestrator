# iOS Dashboard Notifications

## Request

- Fix the `403 Forbidden` response when a driver opens Notifications from the iOS dashboard.
- Show only the 10 latest notifications in the iOS notification inbox.

## Root Cause

The iOS app correctly called:

```text
GET /notifications/api/v1/me/inbox?state=all&page=0&size=30
```

The API gateway source configuration contained allow rules for this route, but production gateway authorization uses the remote RBAC policy published by user-service. User-service had migrations for public contact requests, push devices, and the admin inbox, but no driver inbox rules. Because the remote policy defaults to `DENY`, authenticated driver requests returned `403` before reaching notification-service.

The issue was reproduced with a valid driver token:

| Request | Result before fix |
| --- | --- |
| `GET /payment/api/v1/payment/state` | `200` |
| `GET /notifications/api/v1/me/inbox` | `403` |

This confirmed that authentication was valid and the failure was route authorization.

## Backend Fix

User-service migration `0027-add-notification-driver-inbox-rbac-rules.yaml` adds the authoritative remote-policy rules:

| Name | Methods | Path | Role |
| --- | --- | --- | --- |
| `notification-driver-inbox` | `GET,PATCH` | `/notifications/api/v1/me/inbox/**` | `USER` |
| `notification-driver-inbox-root` | `GET` | `/notifications/api/v1/me/inbox` | `USER` |

The migration updates existing rules by name or inserts missing rules, then increments the policy version only when the policy changes. The gateway refreshes the versioned remote policy and does not require a gateway code change.

## iOS Limit

- Initial and pull-to-refresh requests use `size=10`.
- Pagination and infinite loading are removed from the dashboard notification inbox.
- REST results are defensively truncated to 10.
- SSE-created or updated notifications are sorted newest-first and truncated to 10.
- `unreadCount` remains the backend total. Limiting displayed records must not falsify the dashboard badge.

## Validation

- [x] Valid driver token reproduces the pre-fix `403` while another authenticated endpoint returns `200`.
- [x] User-service test suite passes: 9 tests, 0 failures.
- [x] Liquibase migration applies successfully to PostgreSQL and creates both expected rules.
- [x] RBAC policy version increments after inserting the rules.
- [x] iOS requests `size=10` and retains at most 10 records after REST or SSE updates.
- [ ] User-service TeamCity build succeeds.
- [ ] Production deployment is healthy.
- [ ] Authenticated production inbox returns `200` and no more than 10 records.
