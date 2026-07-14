# Firebase Push Notifications: End-to-End Implementation

## Request

Make Firebase push notifications operational across the gateway, notification service, iOS app, and Android app. The implementation must correct route mismatch, bind device ownership to authenticated identity, unregister devices on logout, add delivery retries and dead-letter handling, and dispatch the `CHARGING_LOW_BALANCE_STOP` event.

## Previous Gaps

| Area | Previous behavior | Resolution |
| --- | --- | --- |
| Gateway route | Mobile clients used `/notification`; production exposed `/notifications` | Clients now use `/notifications`; the singular prefix remains as a compatibility alias |
| Authentication | Device registration trusted `tenantId` and `userId` supplied by the client | Gateway strips identity headers and injects JWT `uid` plus the trusted tenant; the service uses only these headers |
| iOS Firebase project | App configuration referenced a different Firebase project | Both iOS Firebase plist files now reference `electra-hub` and bundle `net.electrahub.driverportalios` |
| iOS APNs capability | No checked-in APNs entitlement | Push Notifications capability and `aps-environment` entitlement are checked in for Debug and Release |
| Android FCM | No Firebase Messaging integration | Added production Firebase config, FCM service, token lifecycle, notification channel, and Android 13 permission request |
| Logout | Device registration remained active | Both mobile apps call the authenticated unregister endpoint before clearing their authenticated session |
| Delivery failure | FCM failures became final failures | Retryable failures receive four total attempts with exponential backoff, then move to a durable DLQ |
| Low balance | `CHARGING_LOW_BALANCE_STOP` was ignored | The domain event is mapped to a push notification with a driver-facing low-balance message |

## Request Path

1. A signed-in mobile app obtains an FCM registration token.
2. The app sends `POST /notifications/api/v1/push/devices` with only `deviceId`, `platform`, `fcmToken`, and `provider`.
3. The API gateway validates the bearer token under the USER RBAC rule.
4. The gateway removes any client-supplied `X-ElectraHub-User-Id` or `X-ElectraHub-Tenant-Id` values.
5. The gateway forwards trusted identity headers derived from the validated JWT and gateway configuration.
6. Notification service stores or updates the registration under the trusted user. If the same physical device is active for another user, the old ownership is deactivated.
7. On logout, the app sends `DELETE /notifications/api/v1/push/devices/{deviceId}` while its bearer token is still valid.
8. Notification service deactivates only the registration owned by the authenticated user.

## Event And Delivery Path

1. A domain event arrives on the notification domain-event queue.
2. `DomainNotificationEventListener` maps supported events to notification channels and content.
3. For PUSH, the orchestrator looks up every active Firebase device for the event recipient.
4. One idempotent notification message is created per device and a dispatch command is published after the database transaction commits.
5. `NotificationDispatchListener` selects the Firebase adapter and attempts delivery.
6. Invalid or unregistered FCM tokens are permanent failures and their device registration is deactivated.
7. Provider outages, unavailable Firebase configuration, and transient adapter exceptions are retryable.
8. Retryable attempts are recorded in a separate transaction and retried with 1, 2, and 4 second delays.
9. After four total attempts, the original command is republished to `notifications.dead-letter` using routing key `notifications.dispatch.dead-letter` and retained in `notifications.dispatch.dlq`.

## Firebase Applications

| Platform | Firebase project | Application identity |
| --- | --- | --- |
| Backend Admin SDK | `electra-hub` | Kubernetes service account secret |
| iOS | `electra-hub` | `net.electrahub.driverportalios`, app ID `1:615539732431:ios:3f976eba76d0e1cc32acba` |
| Android | `electra-hub` | `com.electrahub.driverportal`, app ID `1:615539732431:android:6b9bb9b63f94d6e332acba` |

Service-account credentials and APNs private credentials must never be stored in this repository.

## Mobile Lifecycle

### iOS

- Requests user notification permission and APNs registration.
- Exchanges the APNs registration for an FCM token.
- Registers the device after an authenticated user is available.
- Re-registers when Firebase rotates the token.
- Unregisters the device and deletes the local FCM token before logout completes.
- Uses development APNs environment for Debug and production for Release.

### Android

- Requests `POST_NOTIFICATIONS` at runtime on Android 13 and newer.
- Stores an FCM token delivered while the app process is not signed in.
- Registers the current token after successful login.
- Re-registers rotated tokens while authenticated.
- Displays foreground notification payloads on the `charging-updates` channel.
- Unregisters the device before clearing the bearer token on logout.

## Validation Completed

- Notification service Java 21 Maven test suite passes.
- API gateway Java 21 Maven test suite passes, including trusted identity replacement and anonymous spoof-header stripping.
- Android `testDebugUnitTest assembleDebug` succeeds and processes the production Google Services configuration.
- Both iOS Firebase plist files and the APNs entitlement parse as valid XML.
- Gateway local and authoritative user-service RBAC policies include protected plural and compatibility device routes.
- Deployment charts include the singular route alias, trusted tenant, retry settings, and durable DLQ names.

## Deployment Acceptance

- Build and deploy API gateway and notification service from `develop`.
- Confirm notification service declares `notifications.dispatch.dlq` in RabbitMQ.
- Confirm unauthenticated registration and unregistration return 401 or 403.
- With a real user token, register a synthetic test device and immediately unregister it; verify the returned user belongs to the JWT and cannot be overridden in the request body.
- Install updated iOS and Android builds, grant notifications, log in, and confirm an active row exists per physical device.
- Trigger a charging event and confirm the notification reaches both platforms and the dispatch row reaches `DISPATCHED`.
- Trigger a controlled retryable provider failure and confirm four attempts followed by a DLQ message.
- Trigger `CHARGING_LOW_BALANCE_STOP` and confirm a low-balance push is dispatched.

## Operational Notes

- A backend deployment alone will not change a production count of zero registered devices. Registration occurs only after an updated mobile binary is installed, opened, granted permission where required, and authenticated.
- iOS APNs credential validity and token delivery require a signed physical-device build. The Firebase console must contain a valid APNs authentication key or certificate for the production iOS app.
- Monitor active device count, dispatch outcome counts, invalid-token deactivations, retry counts, and `notifications.dispatch.dlq` depth.
- DLQ replay must be an explicit operator action after the underlying provider or configuration issue is corrected. Preserve the original notification id to retain idempotency.

## Production Rollout Result

Validated on July 13, 2026:

- TeamCity API gateway build `1018` succeeded for revision `125f1b8c` and published image tag `32`.
- TeamCity notification service build `1019` succeeded for revision `94f09c93` and published image tag `3`.
- Argo CD reports both production applications Synced and Healthy at GitOps revision `413a3a5`.
- Production runs `amolsurjuse/api-gateway:32` and `amolsurjuse/notification-service:3` with ready replicas, zero pod restarts, and no recent notification-service errors.
- Firebase secret metadata resolves to project `electra-hub` and a configured service account without exposing credential material.
- RabbitMQ declares `notifications.dispatch.dlq`; its post-rollout depth is zero.
- Anonymous registration through both `/notifications` and `/notification` returns HTTP 401.
- Authenticated registration through both route forms succeeds, binds the stored identity to the JWT user, ignores spoofed client identity fields, and unregisters with HTTP 204.
- Database cleanup confirms no synthetic validation device remains active.
- Production still has zero real active mobile registrations. The updated iOS and Android binaries must be signed, distributed, installed, opened, and authenticated before real FCM/APNs delivery can be proven.

## Post-Rollout Registration Incident

At 01:56 UTC on July 14, domain events for user `eda84789-2a1c-42de-844f-72efd53cea16` reached notification service but were skipped because no active Firebase device existed. Production evidence showed only three deleted synthetic validation registrations, no registration row for the affected user, and no mobile `/push/devices` request reaching notification service.

The mobile registration lifecycle was hardened as follows:

- iOS no longer relies on one silent registration attempt. It retries transient APNs, FCM, and backend failures after 5, 30, and 120 seconds.
- iOS retries registration whenever the authenticated app returns to the foreground.
- iOS waits up to 30 seconds for the APNs device token and logs APNs and backend registration failures through unified logging in both Debug and Release builds.
- Android retries registration after transient failures and rechecks registration when notification permission is granted and whenever the authenticated activity resumes.

After installing the corrected mobile build, validate an `ACTIVE` row for the signed-in user before testing a charging notification. If iOS reports an APNs registration error, verify the app is running as a signed physical-device build and the Firebase iOS application has a valid APNs key or certificate.
