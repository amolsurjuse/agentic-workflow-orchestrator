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

`IDLE` is the driver-facing projection of that state. It is not a new database state and does not change billing, idle-fee caps, unplug authorization, payment settlement, or receipt timing.

## Contract

For active-session REST and SSE payloads:

```json
{
  "status": "IDLE",
  "unplugRequiredToStop": true
}
```

The backend must not expose `SUSPENDED` to driver clients. Admin and operational data may continue using the internal lifecycle value where appropriate.

## Backend Changes

Repository: `session-service`

Commit: `e0a2307` (`fix: expose stopped connected sessions as idle`)

- `DriverChargingOrchestrationService` maps domain `SUSPENDED` to driver `IDLE`.
- `ActiveSessionResponse` normalizes legacy `SUSPENDED` values to `IDLE` during construction and deserialization.
- Redis projections therefore return `IDLE`, including cached maps reconstructed after deployment.
- Elasticsearch writes new current-session documents with `IDLE`.
- Elasticsearch queries temporarily accept both `IDLE` and legacy `SUSPENDED` documents during migration.
- Existing session completion and receipt behavior is unchanged.

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

- 66 Maven tests passed in Linux with JDK 21.
- Added mapping and stale-projection compatibility tests.
- TeamCity `ElectraHub_SessionService_Build` build `#82` succeeded.

Android:

- `:app:assembleDebug` succeeded with JDK 21.
- Debug APK generated successfully.

iOS:

- Existing source files were updated without project-structure changes.
- All `LiveSessionStatus` switch sites were checked for the new enum case.
- No iOS CI pipeline is currently configured in TeamCity or GitHub Actions.

## Deployment

- Image: `amolsurjuse/session-service:82`
- k8s-platform revision: `9961ba3`
- Argo CD application: `session-service-prod`
- Argo state: `Synced / Healthy`
- Deployment: 2 ready, updated, and available replicas

## Production Verification

Session `83c667ac-3ca2-469e-b03f-55037dee40d1` was used to verify the contract:

- PostgreSQL lifecycle status: `SUSPENDED`
- Driver active-session API status: `IDLE`
- `unplugRequiredToStop`: `true`
- Idle fee and cap remained backend-authoritative
- Simulator access remained present for unplug

## Acceptance Criteria

- [x] Stopped-but-connected sessions display as Idle.
- [x] Internal lifecycle remains non-terminal until unplug.
- [x] REST, Redis, Elasticsearch, and SSE use the driver-facing contract.
- [x] Cached legacy `SUSPENDED` projections normalize to `IDLE`.
- [x] iOS decodes and displays `IDLE`.
- [x] Android decodes and displays `IDLE`.
- [x] Existing charging, idle-fee, unplug, and receipt behavior remains unchanged.
- [x] Backend is deployed and verified in production.
