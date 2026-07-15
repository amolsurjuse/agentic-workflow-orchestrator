# Driver Idle Session Status

## Request

When charging has stopped but the vehicle remains connected, show the active driver session as `IDLE` instead of `SUSPENDED`.

## State Semantics

The persisted lifecycle state remains `SUSPENDED` inside `session-service` because it represents a non-terminal session that may:

- Accrue a configured idle fee
- Wait for physical unplug
- Retain connector and transaction correlation
- Return to charging if the charger resumes energy delivery
- Complete only after an accepted terminal event

`Idle` is the driver-facing display label for that state. It is not a new database state and does not change billing, idle-fee caps, unplug authorization, payment settlement, or receipt timing.

## Contract

For backward compatibility with installed mobile versions, active-session REST and SSE payloads retain the existing value:

```json
{
  "status": "SUSPENDED",
  "unplugRequiredToStop": true
}
```

Updated mobile clients render `SUSPENDED` as `Idle`. They also accept a future additive `IDLE` value, but the server must not switch the wire value until supported mobile versions have been released and the compatibility window has passed.

## Backend Changes

Repository: `session-service`

Commits:

- `e0a2307` initially introduced an `IDLE` wire value.
- `3f13bc3` (`fix: preserve active-session status compatibility`) superseded that contract before final delivery.

The final backend behavior preserves `SUSPENDED` across REST, Redis, Elasticsearch, and SSE. This avoids decode failures in already-installed iOS versions whose strict enum does not yet contain `IDLE`. Existing session completion and receipt behavior remains unchanged.

## iOS Changes

Repository: `driver-portal-ios`

Commit: `552deb7` (`fix: display stopped connected sessions as idle`)

- Added native decoding for `IDLE`.
- Retained legacy `SUSPENDED` decoding and displays it as `Idle`.
- Reconciliation treats `IDLE` and legacy `SUSPENDED` as the same stopped-but-connected state.
- Idle status uses the existing orange state treatment.
- Idle sessions remain visible until unplug and receipt completion.

## Android Changes

Repository: `driver-portal-android`

Commit: `7973e28` (`fix: display stopped connected sessions as idle`)

- Added native `IDLE` enum support.
- Retained legacy `SUSPENDED` support.
- Both values display as `IDLE` on the charging screen.

## Validation

Backend:

- 63 Maven tests passed in Linux with JDK 21 after restoring the compatible wire contract.
- TeamCity `ElectraHub_SessionService_Build` build `#83` succeeded.

Android:

- `:app:assembleDebug` succeeded with JDK 21.
- Debug APK generated successfully.

iOS:

- Existing source files were updated without project-structure changes.
- All `LiveSessionStatus` switch sites were checked for the new enum case.
- No iOS CI pipeline is currently configured in TeamCity or GitHub Actions.

## Deployment

- Image: `amolsurjuse/session-service:83`
- k8s-platform revision: `21a8ddc`
- Argo CD application: `session-service-prod`
- Argo state: `Synced / Healthy`
- Deployment: 2 ready, updated, and available replicas

## Production Verification

Session `83c667ac-3ca2-469e-b03f-55037dee40d1` was used to verify the contract:

- PostgreSQL lifecycle status: `SUSPENDED`
- Driver active-session API status: `SUSPENDED`
- Updated iOS display label: `Idle`
- Updated Android display label: `IDLE`
- `unplugRequiredToStop`: `true`
- Idle fee and cap remained backend-authoritative
- Simulator access remained present for unplug

## Acceptance Criteria

- [x] Stopped-but-connected sessions display as Idle.
- [x] Internal lifecycle remains non-terminal until unplug.
- [x] REST, Redis, Elasticsearch, and SSE remain backward compatible.
- [x] iOS displays `SUSPENDED` as Idle and can decode future `IDLE` values.
- [x] Android displays `SUSPENDED` as Idle and can decode future `IDLE` values.
- [x] Existing charging, idle-fee, unplug, and receipt behavior remains unchanged.
- [x] Backend is deployed and verified in production.
