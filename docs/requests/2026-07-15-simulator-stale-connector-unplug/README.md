# Simulator Unplug Lost During Stale Connector Session

## Request

Investigate and fix a charging session that remained `SUSPENDED` in the driver app after the connector was unplugged in the simulator. The expected result was removal from active charging and navigation to the completed receipt.

Production example:

- Session: `48a54ddc-1526-42ed-a1d4-dd52eccde62a`
- Account: `eda84789-2a1c-42de-844f-72efd53cea16`
- Charger: `EH-US-CHG-0301`
- Connector reference: `CON-US-0301`
- OCPP connector number: `1`
- OCPP transaction: `161419700`

## Scope

- `ocpi-simulator`: HMI unplug processing and outbound OCPP delivery
- `web-socket-connector`: simulator connection state and `/send` behavior
- `session-service`: terminal event consumption, active-session projection, and receipt generation
- Redis and PostgreSQL: connector correlation and persisted session state
- TeamCity, image registry, k8s-platform, and Argo CD: build and production deployment

## Expected Flow

1. The simulator verifies the session security code for action `UNPLUG`.
2. The HMI sends its charging-stop command.
3. The simulator sends terminal OCPP messages in protocol order:
   - `StatusNotification(Finishing)`
   - `StopTransaction`
   - `StatusNotification(Available)`
4. `web-socket-connector` forwards those messages to `ocpp-service`.
5. `session-service` correlates the transaction and connector using Redis, completes the session, removes it from the active projection, settles the charge, and generates the receipt.
6. Driver SSE publishes the terminal and receipt events.

## Production Evidence

At `2026-07-15T15:35:20Z`:

- Security-code verification succeeded for `UNPLUG`.
- The HMI stop endpoint returned HTTP 200.
- `StopTransaction` and both `StatusNotification` sends returned HTTP 404 from `web-socket-connector /send`.
- The simulator logged a stale WebSocket connector session and queued a reconnect.
- The local simulator transaction was removed and its connector became `Available`.
- The connector reconnected at `2026-07-15T15:35:34Z`.
- The failed terminal messages were not replayed after reconnection.

Because no terminal OCPP event reached the backend, `session-service` correctly retained the last known `SUSPENDED` state and continued publishing active-session SSE updates.

## Root Cause

`forwardOCPPAction()` delivered every OCPP action in an independent fire-and-forget goroutine. When `/send` returned stale-session HTTP 404 or 409, it marked the connection stale and initiated reconnection but discarded the failed action.

This had two correctness problems:

- Terminal events could be permanently lost during the reconnect window.
- Separate goroutines did not guarantee the required order among `Finishing`, `StopTransaction`, and `Available`.

## Design Fix

The simulator now has one bounded delivery queue per charger.

- Capacity: 128 actions per charger
- Ordering: one worker serializes all sends for that charger
- Isolation: one slow charger does not block another charger
- Normal send timeout: 2 seconds
- Reconnect wait: up to 12 seconds
- Worker lifecycle: lazy creation and exit after 2 minutes idle

For stale `/send` HTTP 404 or 409, the worker:

1. Marks the cached connector session stale.
2. Requests immediate reconnection.
3. Waits for the charger connection to become available.
4. Replays the failed action once.
5. Continues draining later actions in their original order.

Other failures remain visible in logs and are not blindly retried because their delivery outcome may be ambiguous.

## Implementation

Repository: `ocpi-simulator`

- `4878915` - `fix: replay unplug events after connector reconnect`
- `d216feb` - `test: allow ordered connector status delivery`

Changed areas:

- `internal/app/app.go`
- `internal/app/fleet_event_loop.go`
- `internal/app/fleet_event_loop_test.go`
- `internal/app/handlers_fleet_test.go`

The existing RFID and Plug & Charge tests were updated to accept valid background status delivery while retaining strict assertions for OCPP authorization payloads.

## Validation

Automated validation:

- Full Go suite passed three consecutive runs.
- Linux race-enabled test passed for `./internal/app`.
- Stale-connector regression verifies one reconnect and successful ordered replay of `Finishing`, `StopTransaction`, and `Available`.
- TeamCity `ElectraHub_OcppSimulator_Build` build `#41` succeeded.

Deployment validation:

- Image: `amolsurjuse/ocpi-simulator:41`
- k8s-platform production promotion: `01f6251`
- Argo application: `ocpp-simulator-prod`
- Argo state: `Synced / Healthy`
- Deployment: 1 ready and available replica
- `/readyz` and `/healthz`: HTTP 200

## Production Session Recovery

After the connector reconnected, the missing `StopTransaction` and `StatusNotification(Available)` were replayed through the normal OCPP transport.

Final state:

- Database status: `COMPLETED`
- Stop reason: `EV_DISCONNECTED`
- Stopped at: `2026-07-15T15:50:19Z`
- Active-session API for the account: `[]`
- Receipt status: `Completed`
- Idle fee: capped at `$50.00`

## Follow-up Observation

The terminal meter value produced 90.57 kWh on the final receipt, while an earlier active response had shown a lower accumulated energy value. This did not cause the stuck-session defect and was not changed in this fix. Meter continuity between active projections and terminal OCPP values should be investigated as a separate data-consistency request.

## Acceptance Criteria

- [x] Stale connector sessions are detected on `/send` 404 or 409.
- [x] Failed terminal action is replayed after reconnection.
- [x] Per-charger OCPP action order is preserved.
- [x] Delivery backpressure is isolated by charger.
- [x] RFID and OCPP 1.6/2.0.1 Plug & Charge tests remain valid.
- [x] TeamCity build succeeds.
- [x] Production deployment is healthy on image `41`.
- [x] Reported session is no longer active.
- [x] Completed receipt is available to the owning account.
