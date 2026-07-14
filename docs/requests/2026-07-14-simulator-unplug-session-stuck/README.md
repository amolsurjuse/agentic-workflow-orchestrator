# Simulator Unplug Leaves Session Active

## Request

Investigate and fix a driver session that remained `SUSPENDED` and continued accruing idle time after the driver stopped charging and unplugged from the simulator.

Production example:

- Session: `3839ccd2-46be-4a2c-b515-3bbf6b94aacc`
- Charger: `EH-US-CHG-0001`
- Connector reference: `CON-US-0001`
- OCPP connector number: `1`
- OCPP transaction: `1976386174`

## Relevant Flow

1. The driver app sends a remote stop request to `session-service`.
2. `session-service` records the remote-stop intent and preserves an idle-fee session until physical unplug.
3. The simulator emits `StopTransaction`; `session-service` moves the session to `SUSPENDED` because unplug is still required.
4. The driver opens the simulator URL and the simulator verifies the session-scoped security code through `session-service`.
5. The simulator processes unplug, clears its transaction, and emits `StatusNotification(Available)` without a transaction ID, as required for this flow.
6. `session-service` correlates `Available` through the Redis charger and connector mapping, completes the session, clears active projections, settles payment, applies subscription benefits, and generates the receipt.

## Production Evidence

The transport and connector mapping were healthy:

- Security verification succeeded at `2026-07-14T22:10:47Z`.
- Simulator unplug returned HTTP 200 at `2026-07-14T22:10:48Z`.
- `StopTransaction` was received for OCPP transaction `1976386174`.
- `StatusNotification(Available)` was persisted at `2026-07-14T22:10:48Z`.
- Redis retained both connector mappings:
  - `active:connector:EH-US-CHG-0001:1`
  - `active:connector-ref:EH-US-CHG-0001:CON-US-0001`

Despite this, the database session remained `SUSPENDED` and the idle ticker continued publishing updates.

## Root Cause

`session-service` had a 60-second protection window after remote stop. Any `Available` received in that window was treated as a charger-generated transient status and converted back to `SUSPENDED`. This prevents a remote stop from being mistaken for a physical unplug.

The genuine simulator unplug occurred about 56 seconds after remote stop, so the same time-only guard rejected it. The service had no durable signal that the driver had successfully authorized the simulator unplug.

## Design Fix

The fix replaces time-only inference with explicit, short-lived authorization while retaining the original safety guard.

### Authorization marker

When `POST /sessions/{id}/simulator/verify-code` validates action `UNPLUG`, `session-service` writes:

```text
session-service:charging:simulator:unplug-authorized:{sessionId}
```

Properties:

- Session-scoped
- Default TTL of 120 seconds
- Configurable with `app.charging.simulator-unplug.authorization-ttl-seconds`
- Atomically consumed with Redis `GETDEL`
- Removed during terminal-session cleanup

### Status decision

An immediate `Available` completes a remote-stopped idle session only when:

- A valid simulator unplug authorization marker is atomically consumed; or
- The session is card-present and intentionally does not require a security code.

An unsolicited `Available` inside the protection window still leaves the session suspended. Redis failure remains fail-closed.

## Changed Repository

`session-service`

- Commit: `72aa88a` (`fix: complete verified simulator unplug`)
- Branch: `develop`
- Main changes:
  - `ActiveChargingRedisService`: authorization lifecycle and atomic consumption
  - `DriverChargingOrchestrationService`: verification marker and authorized status decision
  - Regression coverage for authorized and unsolicited immediate `Available`

## Verification

### Automated

- Focused tests: 34 passed
- Full session-service tests: 55 passed
- TeamCity build: `ElectraHub_SessionService_Build` number `74`
- Built revision: `72aa88a53bbfb488734b55c84ab7b5cf4d3da15c`

### Deployment

- Image: `amolsurjuse/session-service:74`
- k8s-platform revision: `0cf3c9f70d3e626131328db94d0619f11de705bd`
- Argo CD application: `session-service-prod`
- Final state: `Synced / Healthy`
- Replicas: 2 available, 2 updated

### Production replay

The stuck session was reconciled through normal APIs:

1. Re-verified its existing session security code for `UNPLUG`.
2. Re-emitted the simulator connector's observed `Available` state.
3. Confirmed session status `COMPLETED` with `EV_DISCONNECTED`.
4. Confirmed all session, connector, transaction, idle, and authorization Redis keys were removed.
5. Confirmed simulator connector `1` is `Available` with no active transaction.
6. Confirmed payment settlement, subscription discount, receipt generation, current-index deletion, and receipt-ready publication completed.

## Historical Test Receipt Caveat

This session remained stuck long enough that the delayed replay finalized a test receipt using the later reconciliation timestamp:

- Delayed gross cost: `$52.7363`
- Delayed net cost: `$42.1890`
- Expected cost at the original unplug event: gross `$1.4628`, net `$1.1702` after the 20% subscription discount

The payment record used payment method `CARD` and has no wallet balance movement. A direct database rewrite was intentionally avoided because payment, dashboard, Elasticsearch/current-session, analytics, and receipt projections had already consumed the event. Correcting historical distributed records requires an explicit compensation/reversal workflow, not a partial table update.

## Acceptance Criteria

- [x] Verified simulator unplug completes within the remote-stop protection window.
- [x] Unsolicited immediate `Available` remains protected.
- [x] Card-present unplug remains code-free.
- [x] Authorization is short-lived and single-use.
- [x] Active Redis state is cleared after completion.
- [x] Receipt generation starts only after accepted unplug.
- [x] Production deployment is healthy.
- [x] Reported stuck session is no longer active.
