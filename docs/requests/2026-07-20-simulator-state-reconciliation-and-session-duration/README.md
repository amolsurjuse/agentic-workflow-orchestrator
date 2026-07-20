# Simulator State Reconciliation And Session Duration Safeguard

## Request

Correct the simulator when a connector detail screen reports an offline or error connection while the charger list still reports an active charging transaction. Add a backend safeguard that closes active charging sessions which have remained active or suspended for more than 12 hours.

## Production Evidence

- `EH-US-CHG-0002` returned `connectionState: CONNECTED` and `activeTransactions: 1` from `GET /api/v1/chargers`, while its live connection endpoint returned `connectionState: ERROR`.
- The session database contained three stale `SUSPENDED` sessions started on 7-8 July. They had stopped timestamps but remained driver-visible because idle-fee sessions intentionally wait for an unplug event.

## Root Cause

1. The simulator list used the fleet store's persisted connection state and active transaction list. The detail flow queried the WebSocket connector live, so the two views could diverge.
2. The simulator event loop checked for active transactions before it checked connection state. A disconnected charger with a stale transaction could still emit `Charging` status and metering events.
3. `session-service` reconciled timed-out start attempts and non-idle finishing sessions, but it intentionally left idle-fee sessions open until unplug. There was no hard upper bound for stale `ACTIVE` or `SUSPENDED` sessions.

## Design

### Simulator

- Poll `web-socket-connector` through one bulk `GET /connections` request per reconciliation cycle rather than one request per charger.
- Persist each observed connection state in the fleet store. A cached `CONNECTED` or `CONNECTING` charger missing from the connector response becomes `DISCONNECTED`.
- Treat `CONNECTED` as the sole state that may expose active transactions in the charger list.
- Suppress all simulated charging metering and status emissions unless the charger is currently connected.
- Keep the raw transaction record locally for diagnostic and eventual reconnect behavior, but never present it as an active charging transaction while its connection is offline or errored.

### Session Lifecycle

- Add a configurable server-side maximum duration, enabled by default at 12 hours.
- Inspect only `ACTIVE` and `SUSPENDED` sessions, ordered by `started_at`, in a bounded batch of at most 100 rows per scheduler run.
- Add a `(status, started_at)` database index for the recurring query.
- Atomically claim each eligible session with a conditional update before finalizing it. This prevents the two production replicas from terminating the same session twice.
- Mark the claimed session `COMPLETED` with `TIMED_OUT`, calculate the final capped cost, publish the normal terminal event, queue receipt generation, and remove the driver-visible active session projection.
- For a truly `ACTIVE` transaction, issue a best-effort OCPP remote stop after the transaction commits. For `SUSPENDED` idle-fee sessions, do not issue a duplicate remote stop because the charge point has already stopped energy delivery.
- Keep connector occupancy until an explicit physical `Available` event arrives, while preventing the expired session from remaining visible as active to the driver.
- Ignore a late duplicate OCPP `StopTransaction` for an already terminal session so it cannot recreate a suspended idle session.

## Configuration

| Property | Default | Purpose |
| --- | --- | --- |
| `SESSION_MAXIMUM_DURATION_ENABLED` | `true` | Enables the safeguard. |
| `SESSION_MAXIMUM_DURATION_HOURS` | `12` | Maximum lifetime for `ACTIVE` and `SUSPENDED` sessions. |
| `SESSION_MAXIMUM_DURATION_BATCH_SIZE` | `100` | Limits rows processed in one run. |
| `SESSION_MAXIMUM_DURATION_SCHEDULER_DELAY_MS` | `60000` | Delay between reconciliation cycles. |
| `SESSION_MAXIMUM_DURATION_INITIAL_DELAY_MS` | `30000` | Delay after startup before the first cycle. |

## Acceptance Checks

1. A charger whose live WebSocket state is `ERROR` or `DISCONNECTED` appears offline in the list and has zero visible active transactions.
2. The simulator does not send meter values or a `Charging` status for a disconnected charger with stale local transaction data.
3. A session older than 12 hours in `ACTIVE` or `SUSPENDED` is completed once, receives `TIMED_OUT`, disappears from active-session APIs and produces a receipt.
4. A late OCPP stop callback cannot change that completed session back to `SUSPENDED`.
5. The recurring lookup uses the composite index and bounded pagination so it remains predictable as historical session volume grows.
