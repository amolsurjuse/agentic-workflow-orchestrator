# In-App Account And Payment Notifications

## Original Request

Show successful auto top-up, credit-card add/remove, and profile-update events in
the driver dashboard notification inbox. These events must be in-app only and
must not generate push or email messages. Identify other useful in-app events.

## Product Decision

The notification service remains the single source of truth for the dashboard
inbox. Payment-service and user-service publish domain events after their own
database transactions commit. Notification-service maps the event types to the
`IN_APP` channel only. Mobile clients read the common authenticated inbox API;
they do not create local synthetic notifications.

## Event Catalog

| Event | Owner | Dashboard title | Data policy |
| --- | --- | --- | --- |
| `PAYMENT_CARD_ADDED` | payment-service | Payment card added | Brand and last four digits only |
| `PAYMENT_CARD_REMOVED` | payment-service | Payment card removed | Brand and last four digits only |
| `PAYMENT_AUTO_TOP_UP_ENABLED` | payment-service | Auto top-up enabled | Threshold, amount, currency, masked card |
| `PAYMENT_AUTO_TOP_UP_DISABLED` | payment-service | Auto top-up disabled | No card secret or token |
| `PAYMENT_AUTO_TOP_UP_UPDATED` | payment-service | Auto top-up updated | Threshold, amount, currency, masked card |
| `PAYMENT_AUTO_TOP_UP_COMPLETED` | payment-service | Wallet topped up automatically | Amount, currency, resulting balance, masked card |
| `PAYMENT_WALLET_TOP_UP_COMPLETED` | payment-service | Wallet top-up completed | Amount, currency, resulting balance |
| `USER_PROFILE_UPDATED` | user-service | Profile updated | Changed field names only, never profile values |

Every event above is routed to `IN_APP` only. `PUSH`, `EMAIL`, and `SMS` are
explicitly excluded.

## Reliability And Performance

- Mutation and outbox insert occur in the same database transaction.
- Dispatchers read small ordered batches with `FOR UPDATE SKIP LOCKED`, allowing
  multiple replicas without duplicate ownership or blocking user requests.
- RabbitMQ delivery happens asynchronously outside the API request path.
- Failed deliveries remain retryable in the outbox.
- Notification-service idempotency prevents duplicate inbox records.
- Card PAN, CVV, payment token, full address, phone, name, and email are not
  included in event payloads.

## Client Contract

- iOS already uses `GET /notifications/api/v1/me/inbox?page=0&size=10` and its
  live inbox stream. `payment-*` and `user-*` templates already map to payment
  and account display types.
- Android must replace its obsolete list endpoint with the authenticated paged
  inbox contract and display the server subject/body fields.
- The dashboard keeps the latest ten notifications, matching the current iOS
  requirement.

## Additional Candidate Events

These are useful but are intentionally deferred until their owner-service
lifecycle and frequency rules are designed:

- Subscription activated, renewed, cancelled, expiring soon, and quota at
  80/100 percent.
- Payment failed, refund completed, chargeback opened, and card expiring soon.
- Wallet low-balance warning before charging is blocked.
- Vehicle added/removed and Plug & Charge certificate expiring.
- Favorite charger unavailable, back online, or planned maintenance.
- Terms/privacy version accepted or requiring re-acceptance.

High-frequency meter values, connector status heartbeats, balance reads, and
ordinary dashboard refreshes must never create inbox notifications.

## Repositories

- `payment-service`
- `user-service`
- `notification-service`
- `driver-portal-android`
- `driver-portal-ios` reviewed; no code change expected
- `k8s-platform`

## Validation Plan

1. Unit-test event creation, masked payloads, and outbox dispatch behavior.
2. Assert every new notification event produces exactly one `IN_APP` request.
3. Assert none of the new events produce push or email requests.
4. Build payment-service, user-service, notification-service, and Android.
5. Deploy through TeamCity and Argo CD.
6. Execute card, auto top-up, wallet top-up, and profile mutations in production
   with a controlled account.
7. Verify inbox rows use `channel=IN_APP` and no matching `PUSH` or `EMAIL` rows
   exist.

## Status

Implementation is complete and local verification passed on 2026-07-15:

- payment-service compiled successfully;
- user-service passed 10 tests, including the profile event privacy assertion;
- notification-service passed 29 tests, including all eight `IN_APP`-only events;
- Android unit/build tasks completed and produced a debug APK;
- iOS was contract-reviewed and requires no source change.

Production deployment and live inbox evidence are in progress.
