# Firebase Push Notification Audit

Date: 2026-07-13

## Objective

Identify what remains before Firebase push notifications work reliably from domain event to iOS and Android delivery in production.

## Executive Status

Firebase Admin SDK support exists in `notification-service`, the production service account secret is structurally valid, and real push sending is enabled. Push notification delivery is nevertheless non-functional because no mobile device has registered successfully in production.

Production evidence collected during this audit:

| Check | Result |
| --- | --- |
| Notification service deployment | Healthy, 1/1 available |
| Firebase service-account secret | Present and valid JSON |
| Firebase backend project and service-account project | Match |
| Real push sending | Enabled |
| Active registered devices | 0 |
| Push messages skipped with `NO_ACTIVE_PUSH_DEVICE` | 414,772 |
| Push messages actually dispatched | 0 |
| Old push messages stuck in `PENDING` | 14 |
| Notification service tests | 16 passed, 0 failed |
| Rabbit notification queues | No current backlog |

The highest-volume symptom is not an FCM provider error. The backend repeatedly receives domain events but cannot find a registered mobile device.

## P0: Required To Deliver The First Push

### 1. Correct the public notification API URL

Both mobile projects use the singular path:

- iOS: `driver-portal-ios/DriverPortalIOS/Services/AppServices.swift`
- Android: `driver-portal-android/app/src/main/java/com/electrahub/driverportal/data/network/AppConfig.kt`

Current client base URL:

```text
https://api.electrahub.net/notification
```

The gateway route and notification service context path are plural:

```text
https://api.electrahub.net/notifications
```

The singular prefix has no gateway route. Update both clients and their documentation to `/notifications`.

### 2. Resolve gateway policy drift and remove the dead singular alias

The production remote RBAC policy, version 13, already authorizes authenticated `USER` access to:

```text
POST   /notifications/api/v1/push/devices
DELETE /notifications/api/v1/push/devices/{deviceId}
```

It also contains equivalent singular-path rules. However, the gateway route registry only has the plural `notifications` backend route, so authorizing `/notification/...` does not make that singular prefix routable.

There is also configuration drift: `api-gateway/src/main/resources/application.yaml` does not contain the push-device rules that are present in the remote policy managed by `user-service` change set `0021-add-notification-push-device-rbac-rules.yaml`.

Pending:

- Standardize clients and policy on the plural `/notifications` prefix.
- Remove the misleading singular RBAC aliases after clients are migrated.
- Add the push-device rules to the gateway's local fallback policy, or explicitly document that production requires the remote policy.
- Add tests proving anonymous callers are denied, authenticated drivers are allowed, and the request resolves to the notification service rather than a 404 route miss.

### 3. Bind registrations to the authenticated user

`notification-service` currently trusts `tenantId` and `userId` supplied in the JSON body. The service does not validate those values against authenticated identity. A user could attempt to attach a token to another account after the gateway rule is opened.

Required design:

- Derive the driver ID from a trusted identity propagated by the gateway.
- Do not accept an arbitrary user ID from the mobile client.
- Use a server-owned tenant value or validate it against trusted tenant context.
- Strip client-supplied identity headers at the gateway before adding trusted headers, or use a signed internal identity token.
- Apply the same ownership check to device deletion.

### 4. Align the iOS Firebase project with the backend

The iOS `GoogleService-Info.plist` project does not match the Firebase project configured by the production notification-service secret. Bundle ID and plist bundle ID do match, but backend and client Firebase projects do not.

Use one Firebase project for both the iOS app registration token and the backend Firebase Admin credentials, or configure explicit per-project sending. Validate with a real token after alignment.

### 5. Enable iOS APNs capability and Firebase APNs credentials

The repository contains Firebase Messaging and a `GoogleService-Info.plist`, but it contains no checked-in entitlements file, `aps-environment` entitlement, `CODE_SIGN_ENTITLEMENTS` setting, or Push Notifications capability.

Pending:

- Add the Push Notifications capability to the iOS target.
- Add the correct development/production `aps-environment` entitlement through signed configurations.
- Confirm the Apple APNs authentication key is uploaded to the same Firebase project as the iOS app.
- Add `didFailToRegisterForRemoteNotificationsWithError` telemetry.
- Test on a physical device; the simulator is not sufficient for the final production acceptance test.

### 6. Implement Android FCM support

Android currently has no Firebase push implementation. Missing items include:

- Firebase Google Services Gradle plugin
- Firebase Messaging dependency/BOM
- Environment-appropriate `google-services.json` handling
- `POST_NOTIFICATIONS` runtime permission for Android 13+
- `FirebaseMessagingService`
- FCM token registration and refresh
- Notification channels, icon, sound, and foreground/background handling
- Device unregister on logout and account deletion
- Notification tap/deep-link routing

The Android notification screen currently fetches application data; it is not an FCM receiver.

## P1: Correctness And Reliability

### 7. Stop duplicate charging notifications

The session service publishes idle-started and idle-warning events whenever repeated `SUSPENDED` status notifications arrive. It also emits battery-full for every low-power meter reading after energy is nonzero. Each publication receives a random event ID, so the notification service's idempotency key cannot deduplicate it.

Production volume demonstrates the impact:

- `charging-idle-warning`: 193,383 skipped rows
- `charging-idle-started`: 193,383 skipped rows
- `charging-battery-full`: 20,148 skipped rows

Required behavior:

- Publish lifecycle notifications only on persisted state transitions.
- Store transition-notified markers or deterministic event keys by session and milestone.
- Emit idle warning once at a defined threshold, not simultaneously with idle started and not on every status refresh.
- Emit battery-full once per session after a stable threshold/debounce rule.
- Use deterministic idempotency such as `sessionId:eventType:transitionVersion`.
- Add regression tests for repeated OCPP status and meter events.

### 8. Add missing event coverage

`session-service` publishes `CHARGING_LOW_BALANCE_STOP`, but `notification-service` does not map it to any channel, so it is ignored.

Decide and implement channel behavior for:

| Event | Current behavior | Required decision |
| --- | --- | --- |
| `CHARGING_LOW_BALANCE_STOP` | Ignored | Push with low-balance stop reason and payment action |
| `CHARGING_RECEIPT_READY` | Email only | Add push if receipt-ready notification is expected in mobile apps |
| `CHARGING_IDLE_WARNING` | Push, duplicated | Define one grace-period warning threshold |
| `CHARGING_IDLE_STARTED` | Push, duplicated | Emit only on transition into billable idle state |

### 9. Add retry and dead-letter handling

`NotificationDispatchListener` marks provider failures as `FAILED` and explicitly does not retry. Transient FCM timeouts, HTTP 429, and 5xx responses will therefore be lost.

Implement:

- Error classification: permanent token error vs transient provider error.
- Exponential backoff with bounded attempts and jitter.
- Retry queue and dead-letter queue.
- A recovery/replay operation for dead letters.
- Reconciliation for the 14 existing old `PENDING` rows.

### 10. Remove invalid tokens automatically

When FCM returns `UNREGISTERED` or an equivalent permanent token error, mark that device inactive. Do not repeatedly attempt delivery to invalid tokens. Track the invalidation reason and timestamp without storing provider secrets in logs.

### 11. Complete iOS lifecycle and interaction handling

iOS registers only after authentication and refreshes the FCM token, but it does not currently:

- Clear coordinator user state on logout.
- Delete the backend device registration on logout, account deletion, or user switch.
- Retry registration after transient network/APNs timeout failures.
- Report registration failures outside debug builds.
- Implement foreground presentation callbacks.
- Handle notification taps and route to active session, idle action, or receipt views.

Without cleanup, a reused device can remain associated with the previous account.

### 12. Add platform-specific Firebase payloads

The backend sends a generic notification plus string data. It does not set `AndroidConfig` or `ApnsConfig`.

Add a typed payload contract with:

- `eventType`, `sessionId`, and stable navigation target
- Android priority, channel ID, collapse key, and click action
- APNs sound, badge, category, thread ID, and appropriate content flags
- Non-sensitive display content only
- Contract tests shared with both mobile clients

## P2: Security, Scale, And Operations

### 13. Protect device tokens at rest

The database stores the full FCM token as plaintext along with its hash and masked form. Encrypt the usable token at application level or with a managed data-encryption mechanism. Restrict database access and ensure logs use only the masked value.

Add token-level ownership protection so the same active FCM token cannot silently remain attached to multiple users.

### 14. Expire stale registrations

Add a scheduled cleanup policy based on `last_seen_at`, app reinstall, account deletion, and provider invalidation. Mobile clients should refresh registration on launch/authentication, not only on token refresh.

### 15. Make quota and rate limiting distributed

The 5-per-second limiter is a synchronized in-memory sleep in one listener process. It blocks the listener thread and becomes per-pod if the deployment scales. The daily quota also counts attempts from database state without a reservation mechanism.

Move rate/quota coordination to Redis or a broker-based delayed dispatch design before enabling multiple replicas. Do not count `NO_ACTIVE_PUSH_DEVICE` as provider send attempts.

### 16. Add observability and service resilience

Pending production controls:

- Metrics for registration success/failure by platform
- Active/stale/invalid device gauges
- Event-created, dispatched, skipped, retried, failed, and dead-letter counters
- FCM latency and provider error classification
- Alert when active device count unexpectedly reaches zero
- Alert on duplicate event volume per session
- HPA, PodDisruptionBudget, and ServiceMonitor when traffic justifies scaling
- Startup health indicator that distinguishes missing credentials from provider reachability

The current Firebase credential loader silently falls back to an unconfigured sender on parsing errors, which should instead produce a visible health/readiness signal.

## Test And Acceptance Plan

1. Unit-test gateway authorization and trusted user binding.
2. Unit-test registration, update, deletion, invalid-token cleanup, and retry classification.
3. Add session-service tests proving repeated OCPP status/meter input produces one notification per milestone.
4. Build iOS with the production entitlement and matching Firebase configuration.
5. Build Android with Firebase Messaging and Android 13+ permission handling.
6. Register one physical iOS device and one physical Android device.
7. Verify both active registrations in the production database without exposing tokens.
8. Trigger session started, battery full, idle warning, idle started, low-balance stop, session completed, and receipt ready.
9. Verify foreground, background, terminated-app, and notification-tap behavior.
10. Rotate one token and uninstall one app; confirm old tokens are deactivated.
11. Simulate FCM 429/5xx and invalid-token responses; verify retry and cleanup.
12. Run a burst test and verify bounded queues, no duplicate events, and no listener-thread starvation.

## Recommended Implementation Order

1. Correct the mobile route, align local/remote gateway policy, and add trusted identity binding.
2. Correct iOS URL, align Firebase project, add APNs capability, and complete iOS lifecycle.
3. Register and deliver to one physical iOS device as a vertical-slice proof.
4. Implement Android FCM and prove one Android delivery.
5. Fix session event transition semantics and deterministic idempotency.
6. Add low-balance/receipt event coverage and typed deep links.
7. Add retries, invalid-token cleanup, stale-device cleanup, and token encryption.
8. Add production metrics, alerts, distributed throttling, and full regression/load tests.

## Repositories In Scope

- `api-gateway`
- `notification-service`
- `session-service`
- `driver-portal-ios`
- `driver-portal-android`
- `k8s-platform`
- `agentic-workflow-orchestrator`
