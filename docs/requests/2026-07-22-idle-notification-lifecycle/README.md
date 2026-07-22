# Idle Notification Lifecycle

## Purpose

Keep driver notifications aligned with the actual charging-session lifecycle when a connector has an idle-fee policy. A paused connector that still requires the vehicle to be unplugged remains an active session; it is not a completed session and must not be presented as one.

## Observed Defect

The previous flow emitted all of the following as soon as a session entered `SUSPENDED`:

1. `CHARGING_SESSION_STOPPED`
2. `CHARGING_IDLE_STARTED`
3. `CHARGING_IDLE_WARNING`

This created a contradictory inbox sequence: a stopped-session message appeared before the idle state, and the warning was created even when fees were already effective. Because notification consumers run asynchronously, rows were also ordered by database insertion time rather than the original domain-event time.

## Authoritative Event Contract

For a session that requires unplugging after charging pauses, the permitted driver-facing sequence is:

1. `CHARGING_SESSION_STARTED` when OCPP confirms the transaction has started.
2. `CHARGING_IDLE_STARTED` exactly once when the session transitions into `SUSPENDED`, idle fees are enabled, and unplugging is required.
3. `CHARGING_IDLE_FEE_STARTED` exactly once after the first whole billable idle minute (and after any configured grace period). The message tells the driver that fees are now accruing.
4. `CHARGING_SESSION_STOPPED` only after terminal completion, normally after a valid unplug/Available status.
5. `CHARGING_RECEIPT_READY` or `PAYMENT_RECEIPT_READY` only after receipt finalization.

`CHARGING_IDLE_WARNING` remains supported for a future grace-period warning scheduler. It must not be emitted immediately when idle starts.

## Ordering and Delivery Rules

- Session service uses Redis notification milestones (`idle-started`, `idle-fee-started`) to suppress repeat publishes while a session is active.
- Notification service retains the source domain event timestamp on the notification's existing `created_at` field. This is the inbox sort key and requires no schema migration or new index.
- The incoming HTTP notification API cannot set this internal timestamp; it is populated only by the domain-event listener.
- Push and in-app copies share the same source time. The realtime command also carries that time for consistent client behaviour.
- If Redis is unavailable, downstream session-scoped idempotency remains the fallback protection.

## Client Behaviour

The mobile inbox sorts by `createdAt` descending. The new `charging-idle-fee-started` template is classified as an alert in the iOS client. This produces the visible order:

`Receipt ready` -> `Session stopped` -> `Idle fees have started` -> `Idle period started` -> `Session started`.

## Validation

- Unit-test the transition eligibility for `SUSPENDED` and the first billable whole minute.
- Unit-test preservation of the domain `occurredAt` timestamp through notification submission.
- Run the session-service and notification-service Maven test suites.
- Exercise a charger with idle fees: start, remotely stop, wait through one billable minute, unplug, and confirm a single notification for each lifecycle milestone.
