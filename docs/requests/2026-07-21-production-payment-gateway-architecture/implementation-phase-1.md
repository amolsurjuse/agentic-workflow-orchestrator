# Payment Start and Authorization Lifecycle: Implementation Phase 1

Status: Implemented locally and verified with focused service tests

Date: 2026-07-21

Scope: `session-service` and `payment-service` only. This is the first
implementation slice of the production payment-gateway architecture described
in `README.md`.

## Objective

Make the boundary between a requested charger start, an accepted remote command,
an actual physical charging start, and a financial authorization explicit and
durable. A command acknowledgement alone is not proof that charging began and
must never be treated as proof for financial capture, a completed UI state, or
a `CHARGING_SESSION_STARTED` notification.

## State Model

### Payment authorization

| State | Meaning | Allowed next states |
| --- | --- | --- |
| `AUTHORIZED` | Hold/reservation created; no start request is in flight. | `START_PENDING`, `RELEASED`, `EXPIRED` |
| `START_PENDING` | Durable start attempt exists and physical start proof is awaited. | `START_CONFIRMED`, `START_CONFIRMATION_UNKNOWN`, `RELEASE_PENDING` |
| `START_CONFIRMED` | OCPP `StartTransaction` evidence was received and the payment service confirmed it. | `CONSUMED`, `RELEASE_PENDING` |
| `START_CONFIRMATION_UNKNOWN` | The remote command or charger state is ambiguous. The hold remains in place. | `START_CONFIRMED`, `RELEASE_PENDING` only after verified no-start evidence |
| `RELEASE_PENDING` | A void/release is durably requested and awaits a gateway/provider result. | `RELEASED`, `START_CONFIRMATION_UNKNOWN` on a provider uncertainty |
| `RELEASED` | Hold/reservation has been released/voided. | terminal |
| `CONSUMED` | Final settlement/capture was recorded. | terminal except refund workflow |
| `EXPIRED` | A pre-start hold expired before a start attempt was made. | terminal |

### Start attempt

`payment_session_start_attempt` stores a stable attempt ID, session ID,
authorization ID, correlation ID, command state, physical start state,
deadline, OCPP transaction reference, and compensation status. It provides a
recovery record that survives retries, service restarts, and delayed OCPP
events.

## Request Flow

```mermaid
sequenceDiagram
    participant App as Driver app or portal
    participant Session as session-service
    participant Payment as payment-service
    participant Charger as Charge point / OCPP

    App->>Session: Start charging
    Session->>Payment: Create payment authorization
    Payment-->>Session: AUTHORIZED
    Session->>Payment: Create durable start attempt
    Payment-->>Session: START_PENDING + deadline
    Session->>Charger: RemoteStartTransaction
    Charger-->>Session: Command accepted, rejected, or uncertain
    Session->>Payment: Persist command result

    alt Charger emits StartTransaction
        Charger->>Session: StartTransaction(transactionId, meterStart)
        Session->>Payment: Confirm physical start
        Payment-->>Session: START_CONFIRMED
        Session-->>App: Active charging update
    else Explicitly rejected/unavailable
        Session->>Payment: Release authorization
        Payment-->>Session: RELEASED
        Session-->>App: Start failed
    else Transport timeout or uncertain charger state
        Session->>Payment: Mark confirmation unknown
        Session-->>App: Pending; do not create a duplicate session
    end
```

## Evidence Rules

1. `RemoteStartTransaction` acceptance means only that the charge point accepted
   a command. It does **not** mean the vehicle began charging.
2. An OCPP `StartTransaction` event with transaction/meter evidence is the
   authoritative physical-start signal.
3. A failed transport call, a timeout, a stale connector state, or a missing
   Redis entry is an **unknown** result. It cannot cause an automatic hold
   release or session terminalization.
4. A timeout may release a hold only after a connector status observed after the
   start request proves `AVAILABLE`, `UNAVAILABLE`, `FAULTED`, or
   `INOPERATIVE` and no physical start was recorded.
5. A late `StartTransaction` after a release creates a `STOP_AND_RECONCILE`
   recovery action. It never silently captures an unheld payment.
6. The `CHARGING_SESSION_STARTED` notification is emitted only after physical
   start processing, not after remote-command acceptance.

## Durability and Idempotency

- Start attempts are idempotent by session/correlation key.
- Command result, physical-start confirmation, unknown confirmation, and
  release calls use idempotency keys.
- Recovery actions are durable records. Their provider-facing execution is a
  later gateway-adapter phase; a provider outage must not erase the action.
- Wallet reserve calculations include pending and unknown start attempts so a
  user cannot over-commit their wallet while confirmation is outstanding.

## Latency and Failure Boundaries

| Boundary | Synchronous purpose | Asynchronous/recovery behavior |
| --- | --- | --- |
| Session -> payment authorization | Reject an ineligible start before OCPP. | Idempotent retry only with the original correlation ID. |
| Session -> durable start attempt | Record the recoverable intent before command dispatch. | No client-side retry without reading the existing attempt. |
| Session -> OCPP remote start | Request a charger action. | OCPP `StartTransaction` remains the final proof. |
| Session -> payment confirmation | Persist physical evidence. | Pending confirmations are retried from a bounded oldest-first batch. |
| Timeout reconciliation | Release only with verified no-start connector evidence. | Unknown/stale state remains recoverable and visible for operations. |

## Implemented Interfaces

### payment-service internal APIs

```text
POST /api/v1/payment/internal/session-authorizations/{sessionId}/start-attempts
POST /api/v1/payment/internal/session-authorizations/{sessionId}/command-results
POST /api/v1/payment/internal/session-authorizations/{sessionId}/physical-start-confirmations
POST /api/v1/payment/internal/session-authorizations/{sessionId}/start-confirmation-unknown
POST /api/v1/payment/internal/session-authorizations/{sessionId}/release
```

### New persistence

Payment migrations add:

- payment authorization lifecycle fields
- `payment_session_start_attempt`
- `payment_recovery_action`

Session migrations add:

- payment start-attempt ID and deadline
- payment confirmation state/timestamps
- payment authorization release timestamp

## Verification Completed

| Check | Result |
| --- | --- |
| `payment-service` compile with JDK 21 | Passed |
| Payment lifecycle unit tests | Passed |
| `session-service` compile with JDK 21 | Passed |
| Focused session lifecycle/Redis tests | Passed |
| Full `session-service` unit test suite | Passed |

## Deliberately Deferred to the Next Implementation Slices

1. `payment-gateway-service`, provider adapter SPI, capability routing, and
   provider secret references.
2. Provider-backed void, capture, refund, inquiry, webhook verification,
   retries, dead-letter investigation, and reconciliation imports.
3. System-admin payment route configuration UI and audit views.
4. Driver and admin payment lifecycle/receipt presentation.
5. Provider contract tests and end-to-end sandbox regression runs.
