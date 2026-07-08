# Performance and Latency Implementation Progress

Date: 2026-07-07
Request: Start implementing the performance and latency audit plan step by step, preserve existing functionality, and run full regression after the combined change set.
Status: In progress.

## Working Rules

- Keep changes incremental and low-risk.
- Do not intentionally break existing behavior.
- Prefer configurable guardrails over hard-coded behavior.
- Avoid touching repositories with existing local user changes until those changes are understood.
- Run focused compile/build checks as each affected repo changes.
- Run the full regression suite after the combined implementation set is ready.

## Repository Status Notes

- `api-gateway`: clean `develop` before edits.
- `session-service`: clean `develop` before edits.
- `payment-service`: clean `develop` before edits.
- `pricing-service`: source folder was not present at `C:\development\project\pricing-service`; no direct edits made.
- `admin-portal-ui`: existing local modification in `src/pages/DashboardPage.tsx`; defer edits until reviewed.
- `driver-portal-android`: existing local modifications across app/view-model/network files; defer edits until reviewed.
- `driver-portal-ios`: clean `develop` before edits.

## Completed Changes

### API Gateway

- Added configurable downstream REST timeouts:
  - `gateway.http-client.connect-timeout`
  - `gateway.http-client.read-timeout`
  - `gateway.http-client.streaming-connect-timeout`
- Kept SSE duration unbounded, but made streaming connect timeout configurable.
- Validation:
  - Docker build completed successfully with image `electrahub-api-gateway-perf-check`.

### Session Service

- Added configurable SSE lifecycle guardrails:
  - `app.charging.sse.max-emitters-per-account`
  - `app.charging.sse.stream-timeout-ms`
- Capped duplicate open SSE emitters per account.
- Cleaned empty emitter lists from the local emitter registry.
- Preserved existing unit-test constructor.
- Validation:
  - Docker build completed successfully with image `electrahub-session-service-perf-check`.
- Added shared outbound RestClient timeout configuration:
  - `app.http-client.connect-timeout`
  - `app.http-client.read-timeout`
- Validation:
  - Docker build completed successfully again with image `electrahub-session-service-perf-check`.
- Added OCPP stop callback fallback resolution for OCPP 2.0.1 `TransactionEvent(Ended)`:
  - Primary lookup remains transaction id.
  - If transaction lookup misses, session-service can resolve the active session by charger + connector context supplied by OCPP-service.
  - This keeps `StatusNotification(Available)` protocol-compliant and does not add transaction id to Available status events.
- Protocol reference:
  - OCA protocol page confirms OCPP 1.6 is widely used and supports SOAP/JSON.
  - OCA download page provides the official OCPP specification download path with or without an account.
- Validation:
  - `mvn -q test` completed successfully in the session-service Maven container.
  - Docker build completed successfully with image `electrahub-session-service-stop-fallback-check`.

### OCPP Service

- Updated OCPP 2.0.1 `TransactionEvent(Ended)` callback forwarding:
  - Includes charge point id and EVSE/connector id in the internal session-service stop callback payload.
  - Preserves existing OCPP 1.6 `StopTransaction` behavior where only transaction id is available from the protocol message.
- Updated handler tests to assert charger + connector context is forwarded for ended transaction events.
- Validation:
  - `mvn -q test` completed successfully in the ocpp-service Maven container.
  - Docker build completed successfully with image `electrahub-ocpp-service-stop-fallback-check`.

### OCPP Simulator Protocol Correction

- Rejected and backed out the attempted simulator-side transaction id on `Available`.
- `StatusNotification(Available)` remains connector-state only; transaction identity stays on `StopTransaction` / OCPP 2.0.1 `TransactionEvent(Ended)`.
- Validation:
  - `go test ./internal/app` completed successfully in the Go container.

### Payment Service

- Added nullable `idempotency_key` to `payment.payment_topup`.
- Added partial unique index for non-null wallet top-up idempotency keys.
- Used session balance-check idempotency for automatic top-ups.
- Normalized session balance-check top-up idempotency keys to a fixed SHA-256 key so long client idempotency strings cannot exceed the database column.
- Prevents duplicate auto top-ups under retries, polling, or load-test duplicate calls.
- Manual top-ups remain unchanged.
- Validation:
  - Docker build completed successfully with image `electrahub-payment-service-perf-check`.
  - Docker build completed successfully again after fixed-length idempotency hardening.

### Billing Service

- Added configurable admin analytics query guardrails:
  - `app.analytics.query.max-range-days`
  - `app.analytics.query.max-offset`
- Mirrored the same settings in the local profile.
- This prevents runaway dashboard queries while keeping normal current/previous-period dashboard filters available.
- Validation:
  - Docker build completed successfully with image `electrahub-billing-service-perf-check`.

### Admin Portal UI

- Added shared fetch timeout support in `src/api/http.ts`.
- Preserved caller-provided abort signals and token-refresh retry behavior.
- Existing dashboard previous-period comparison changes were left intact.
- Validation:
  - `npm.cmd run build` completed successfully.

### Driver Portal iOS

- Preserved idle/unplug-required active charging sessions when SSE snapshots or polling refreshes are empty.
- This protects the remote-stop idle flow from jumping to no-active-session before unplug completes.
- Validation:
  - Syntax build not run yet; Xcode toolchain validation remains pending.

### User Service and iOS Charger Preferences

- Confirmed the existing workspace change set includes backend-backed recently used chargers and favorites:
  - `GET /api/v1/charger-preferences`
  - `POST /api/v1/charger-preferences/recent`
  - `POST /api/v1/charger-preferences/favorites`
  - `DELETE /api/v1/charger-preferences/favorites/{stationId}`
- Preferences are stored per authenticated user in `user_charger_preferences` with recent and favorite indexes.
- iOS already has `ChargerPreferenceStore` plus service calls that optimistically update local state and sync with the backend.
- Validation:
  - `mvn -q -DskipTests package` completed successfully in the user-service Maven container.
  - Docker build completed successfully with image `electrahub-user-service-preferences-check`.

## Next Implementation Areas

- Deploy the session-service and ocpp-service changes before rerunning production JMeter, because the 50-user failure observed earlier was against the previous deployed stop-callback behavior.
- Rerun the full JMeter charging regression after deployment.

## Regression Run - 2026-07-08

- Ran production charging feature regression:
  - Suite: `scripts/jmeter/08-charging-feature-regression-suite.jmx`
  - Output: `C:\development\project\k8s-platform\outputs\jmeter\codex-regression-50-20260708-01`
  - Users: 50 full charging users plus one focused user for each feature scenario.
  - Target API: `https://api.electrahub.net`
  - Target simulator: `https://ocpp-simulator.electrahub.net`
- Result:
  - 38 completed samples.
  - 37 passed.
  - 1 failed.
  - Error rate: 2.63%.
- Failure:
  - Scenario: `Subscription discount active and receipt pricing`
  - Session: `10aa95d0-bd2d-458e-a947-4d5612883347`
  - Charger/connector: `EH-US-CHG-0006` / connector `1`
  - Failure message: session still appeared in `/session/api/v1/sessions/active` after stop.
  - Cleanup physical stop returned simulator `404 transaction not found`, then fallback `StatusNotification(Available)` was accepted but did not clear the active session.
- Interpretation:
  - This is consistent with the previously observed production behavior before the local OCPP-service/session-service stop fallback is deployed.
  - The local fix keeps `StatusNotification(Available)` protocol-compliant and instead makes OCPP 2.0.1 `TransactionEvent(Ended)` carry charger + connector context to session-service as a fallback when transaction lookup misses.

## Redis Connector Status Decision - 2026-07-08

- Added connector-scoped Redis status projection in session-service:
  - Keyed by charger and connector number.
  - Stores the latest OCPP status notification context against the connector.
  - Keeps active-session connector mappings as the authoritative fast path for deciding whether a charger status update belongs to the active session.
- Updated unplug handling so `StatusNotification(Available)` can complete a waiting idle/unplug session when Redis confirms the connector is mapped to that same active session.
- Preserved the immediate-available protection when Redis has no matching connector mapping, so unrelated or stale `Available` events do not prematurely close a session.
- Kept OCPP status notifications protocol-compliant; no transaction id is added to explicit `Available` status events.
- Code:
  - `C:\development\project\session-service\src\main\java\com\electrahub\session\service\ActiveChargingRedisService.java`
  - `C:\development\project\session-service\src\main\java\com\electrahub\session\service\DriverChargingOrchestrationService.java`
  - `C:\development\project\session-service\src\test\java\com\electrahub\session\service\DriverChargingOrchestrationServiceTest.java`
- Validation:
  - `docker run --rm -v C:\development\project\session-service:/workspace -w /workspace maven:3.9.11-eclipse-temurin-21 mvn -q test` passed.
  - `docker build -t electrahub-session-service-redis-connector-status-check C:\development\project\session-service` passed.

## Regression Rerun - 2026-07-08

- Ran production charging feature regression after the Redis connector-status decision was available on `origin/develop`:
  - Suite: `scripts/jmeter/08-charging-feature-regression-suite.jmx`
  - Output: `C:\development\project\k8s-platform\outputs\jmeter\codex-regression-50-20260708-03`
  - Users: 50 full charging users plus one focused user for each feature scenario.
  - Target API: `https://api.electrahub.net`
  - Target simulator: `https://ocpp-simulator.electrahub.net`
- Result:
  - 55 completed samples.
  - 55 passed.
  - 0 failed.
  - Error rate: 0.00%.
- Covered feature labels:
  - `Full charging journey with SSE`: 50 passed.
  - `Idle-fee stop requires unplug`: 1 passed.
  - `Subscription discount active and receipt pricing`: 1 passed.
  - `Low-balance meter triggers backend stop`: 1 passed.
  - `Low-balance decision without auto top-up`: 1 passed.
  - `Auto top-up recovers low wallet`: 1 passed.
