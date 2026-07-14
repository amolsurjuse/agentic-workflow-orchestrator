# Unique Charging Notifications

Date: 2026-07-13
Priority: High
Status: Implemented and locally verified; production deployment pending

## Problem

Repeated OCPP `StatusNotification` and `MeterValues` messages generated the same logical idle and battery-full notification many times. Each session-service publication used a random event ID, so notification-service treated every repeat as a new notification even though its database already had a uniqueness constraint.

Production evidence before the fix:

| Template | Skipped rows |
| --- | ---: |
| `charging-idle-warning` | 193,383 |
| `charging-idle-started` | 193,383 |
| `charging-battery-full` | 20,148 |
| All `NO_ACTIVE_PUSH_DEVICE` push rows | 414,772 |

## Root Cause

1. `session-service` emitted idle events on every `SUSPENDED` status update, not only on transition into `SUSPENDED`.
2. Battery-full was emitted on every meter sample at or below 250 W after any delivered energy.
3. `NotificationEventPublisher` assigned a random UUID to every publication.
4. `notification-service` built idempotency from that random event ID, so repeated logical milestones had different database keys.

## Implemented Design

### Consumer-side uniqueness

`notification-service` now derives a stable charging idempotency key from:

```text
tenantId + eventType + sessionId
```

The seed is represented as a name-based UUID and prefixed with `charging:`. All repeated deliveries for the same session milestone therefore use the same key and resolve through the existing unique constraint on:

```text
idempotency_key + channel + recipient_ref
```

This is the deployment safety boundary: notification-service suppresses duplicates even if an older producer or RabbitMQ redelivery sends them.

### Producer-side event identity

`session-service` now assigns a stable event ID from the same session milestone identity. Repeated publications therefore carry the same broker event identity.

### Producer-side transition guards

`session-service` now publishes:

- Idle started/warning only when a session transitions into `SUSPENDED` and idle fees are enabled.
- Battery full only when power crosses from above 250 W to 250 W or below after positive energy delivery.

Steady `SUSPENDED` updates and steady low-power meter samples no longer publish notification events.

## Performance Characteristics

- No schema migration or new session columns.
- No additional database read/write on meter or status hot paths.
- Constant-time status and power comparisons.
- Reduced RabbitMQ traffic and notification-service work.
- Existing database uniqueness remains the final consistency boundary across service replicas.

## Files Changed

### notification-service

- `src/main/java/com/electrahub/notification/service/DomainNotificationEventListener.java`
- `src/test/java/com/electrahub/notification/service/DomainNotificationEventListenerTest.java`

### session-service

- `src/main/java/com/electrahub/session/service/DriverChargingOrchestrationService.java`
- `src/main/java/com/electrahub/session/service/NotificationEventPublisher.java`
- `src/test/java/com/electrahub/session/service/DriverChargingOrchestrationServiceTest.java`
- `src/test/java/com/electrahub/session/service/NotificationEventPublisherTest.java`

## Verification

| Service | Result |
| --- | --- |
| notification-service | 19 tests passed, 0 failed |
| session-service | 52 tests passed, 0 failed |
| `git diff --check` | Passed |

Regression coverage proves:

- Two random broker event IDs for one session milestone produce the same notification idempotency key.
- Different milestones for the same session remain distinct.
- Repeated session publications use the same deterministic event ID.
- `ACTIVE -> SUSPENDED` emits the idle milestone while `SUSPENDED -> SUSPENDED` does not.
- A downward crossing of the low-power threshold emits battery full while steady low power does not.

## Rollout Order

1. Deploy `notification-service` first so consumer-side deduplication protects production immediately.
2. Deploy `session-service` second to stop duplicate broker traffic at the source.
3. Run one idle-fee charging flow and one battery-full simulation.
4. Verify only one row exists per session, event type, channel, and device.
5. Compare notification row growth for at least 15 minutes against session event volume.

## Production Queries

Growth after deployment:

```sql
SELECT template_id, status, count(*), max(created_at)
FROM notification.notifications
WHERE channel = 'PUSH'
  AND created_at >= :deployment_time
GROUP BY template_id, status
ORDER BY template_id, status;
```

Duplicate check for new charging milestones:

```sql
SELECT idempotency_key, channel, recipient_ref, count(*)
FROM notification.notifications
WHERE created_at >= :deployment_time
  AND idempotency_key LIKE 'charging:%'
GROUP BY idempotency_key, channel, recipient_ref
HAVING count(*) > 1;
```

Expected result: zero duplicate groups.

## Existing Data Cleanup

The fix stops new duplicate growth but intentionally does not delete the existing 414,772 audit rows during application deployment. Historical cleanup should run separately in bounded batches after retention requirements are confirmed, avoiding a large delete and vacuum spike during the production rollout.

