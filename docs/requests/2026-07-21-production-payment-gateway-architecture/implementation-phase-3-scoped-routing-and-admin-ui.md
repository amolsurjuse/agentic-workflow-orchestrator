# Implementation Phase 3: Scoped Routing And System-Admin Configuration

## Purpose

This phase makes payment configuration safe for multi-network ElectraHub operation. It adds a route lookup that derives settlement selection from the canonical ownership snapshot stored with the charging session, rather than accepting a merchant account supplied by a client or a UI.

The phase also adds a system-admin configuration workspace for the three deliberate setup steps:

1. gateway connection;
2. merchant settlement account;
3. payment route.

The workspace remains feature-flagged off until the service, API route, internal credential, and a sandbox connection have been deployed and verified together.

## Tenant-Safe Route Selection

The session service already persists server-resolved `enterpriseId`, `networkId`, `locationId`, and charger identity before it sends a remote start command. The gateway control plane now accepts this immutable scope through `ScopedRouteResolutionRequest`.

Required routing inputs:

| Input | Source | Why it is trusted |
| --- | --- | --- |
| Enterprise ID | Canonical charger ownership snapshot | Not accepted from the driver client |
| Network ID | Canonical charger ownership snapshot | Not accepted from the driver client |
| Charging country | OCPI location identifier from canonical charger inventory | Parsed only from a valid `CC*...` OCPI location identifier; never accepted from the driver client |
| Presentment currency | Charger price plan | Represents the currency in which the driver is billed |
| Channel | Trusted application channel, to be wired before enforcement | Differentiates mobile, web, and terminal support |
| Payment method | Server-side payment flow | Differentiates card-on-file and card-present capability |
| Required capabilities | Payment operation policy | Prevents use of a provider missing required actions |

Resolution order is deterministic:

1. exact enterprise + network merchant account;
2. enterprise-level merchant account with no network assignment;
3. route priority, configuration version, and route identifier.

There is no cross-network, cross-enterprise, or client-selected merchant-account fallback. A missing route returns `PAYMENT_ROUTE_NOT_CONFIGURED` rather than selecting an arbitrary provider.

### Immutable Country Snapshot

`charger-management-service` now supplies `chargingCountry` in its internal
ownership response. It parses the first ISO 3166-1 alpha-2 component of a
valid OCPI location identifier, such as `NL*EHB*LOC*AMS001`. A malformed or
legacy identifier remains unresolved; the payment route guard will fail closed
when enforcement is enabled rather than infer a country from a driver request,
wallet currency, or CPO name.

`session-service` persists the value in `charging_sessions.charging_country`
when it creates a session. The existing bounded ownership backfill also fills
the field for historic sessions using the same batch inventory lookup and
Redis coordination lock. This keeps start-path latency unchanged: it adds a
column to the already-required ownership snapshot, not another network call.

## Reversible Operations

The control plane now supports audited state transitions:

| Resource | Safe actions | Guard |
| --- | --- | --- |
| Gateway connection | Validate, activate, disable | Activation requires a validated connection; production mock activation is rejected |
| Merchant account | Activate, disable | Activation requires an active gateway connection |
| Payment route | Enable, disable | Enable requires an active merchant account and active connection |

Each mutation increments the route or connection configuration version where relevant, writes a configuration audit record, and clears the bounded local route cache. There are no destructive delete endpoints for financial configuration.

## Administrative UI

`admin-portal-ui` now has a system-admin-only, feature-flagged **System Configuration > Payment Configuration** workspace. It includes vertically scoped tabs for:

1. Connections: provider, environment, endpoint profile, and secret references only;
2. Merchant accounts: legal entity, enterprise/network scope, merchant country, settlement currency, and allowed presentment currencies;
3. Payment routes: charging country, billing currency, settlement currency, channel, payment method, priority, validity window, and required provider capabilities.

No secret value, API key, card number, provider token, provider transaction reference, or secret-manager reference is returned by the read API or rendered in the UI. The configuration snapshot exposes only safe state such as provider, environment, endpoint profile, capabilities, configured/not-configured indicators, validation status, and version.

### Safe Configuration Management

The system-admin API is deliberately separate from runtime payment APIs and is protected twice: the API gateway requires `SYSTEM_ADMIN`, and `payment-gateway-service` verifies the signed administrative access context before executing every endpoint.

| Resource | Read | Edit policy | Secret handling |
| --- | --- | --- | --- |
| Gateway connection | Safe configuration snapshot | Disable, edit endpoint profile or write-only references, then validate and activate | Raw values and secret references never return; blank update fields retain the configured secret reference. |
| Merchant account | Settlement scope, country, currencies, status | Disable before editing settlement metadata; connection and enterprise/network scope remain immutable for audit integrity | No gateway credential or payment data exists on this model. |
| Payment route | Market, currency, channel, payment method, capabilities, priority, status | Disable before editing, then explicitly enable after review. Enable revalidates the active merchant connection, settlement currency, capability set, and effective period. | No driver/card/provider token exists on this model. |

Every edit uses the resource `configurationVersion`. The write compares that version in the database and rejects a stale edit instead of silently overwriting another administrator's change. Each mutation is audited and invalidates route-resolution caches.

The UI provides loading, empty, error, and action-in-progress states. It deliberately does not enable the feature in the deployed admin portal yet.

## Driver Payment Reference Propagation

The payment boundary now accepts only an opaque saved-card or future provider
payment-method reference. It verifies that the selected reference belongs to
the driver's active wallet card before authorizing the start.

- iOS already sends its selected `cardId`; the session service now persists and
  forwards it to payment authorization.
- Android now prefers the driver's default saved card, falls back to the first
  active card, forwards that opaque identifier, and blocks a card-funded start
  with a clear local error when no card is present.
- No PAN, CVV, or secret token is added to a session, log, route request, or
  admin UI.

The legacy card model remains a demo compatibility path until hosted/mobile
tokenization replaces raw-card entry. It must not be used to activate a live
PSP route.

## Feature-Flagged Route Guard

`payment-service` now contains a short-timeout route guard for `CARD` and
`CREDIT_CARD` start authorizations. It sends only immutable routing context to
`payment-gateway-service`:

```text
enterpriseId + networkId + chargingCountry + charging currency
+ MOBILE + CARD_ON_FILE + {AUTHORIZE, STATUS_QUERY}
```

The current start endpoint is used by iOS and Android, so the initial channel
is `MOBILE`. The web driver portal does not currently start sessions. Before a
web start flow is introduced, it must send a server-classified `WEB` channel;
the system must never trust a client-supplied channel parameter.

Controls:

| Setting | Default | Effect |
| --- | --- | --- |
| `PAYMENT_GATEWAY_ROUTING_ENABLED` | `false` | Turns on shadow route lookup for the explicit pilot-network allowlist. |
| `PAYMENT_GATEWAY_PILOT_NETWORK_IDS` | empty | No network is evaluated until an operator lists it. |
| `PAYMENT_GATEWAY_ROUTING_ENFORCEMENT_ENABLED` | `false` | Rejects an opted-in card start when route context, gateway authentication, or route configuration is invalid. |
| `PAYMENT_GATEWAY_ROUTING_CONNECT_TIMEOUT_MS` | `200` | Bounds connection setup latency. |
| `PAYMENT_GATEWAY_ROUTING_READ_TIMEOUT_MS` | `500` | Bounds the route-decision latency budget. |

When shadow mode sees a rejected route, it emits a structured server warning
and leaves the legacy demo authorization unchanged. When enforcement is enabled
for an explicit pilot network, the same deterministic failure blocks the start
before OCPP remote start. This increment performs route eligibility only. It
does **not** claim to perform a provider authorization; that requires the
tokenized adapter and durable provider-operation lifecycle in the next phase.

## Latency And Failure Behavior

- Approved route decisions are cached in-process for the configured bounded TTL.
- Each cache lookup verifies a shared Redis configuration generation, so a route mutation on one pod invalidates entries on every pod.
- If Redis cannot be read within its short timeout, the cache is bypassed and the durable database configuration is resolved instead of using a stale approval.
- Every configuration mutation clears its local entries and increments the shared generation.
- External provider calls remain outside database transactions and use durable idempotency records.
- A provider timeout becomes `PENDING_RECONCILIATION`; recovery performs status inquiry only and never blindly repeats a financial mutation.

## Validation Completed

- `payment-gateway-service`: Maven test suite passed with JDK 21.
- `admin-portal-ui`: TypeScript and Vite production build passed.
- A focused test verifies that scope-derived resolution uses the canonical scope request and caches an approved decision.
- `charger-management-service`: Maven test suite passed after extending internal ownership with canonical charging country.
- `session-service`: Maven test suite passed after persisting and backfilling charging country and forwarding scoped payment context.
- `payment-service`: Maven test suite passed, including feature-flag/pilot-scope/fail-closed route-guard tests.
- `payment-service`: an HTTP contract test verifies the shared internal-service header and confirms that a saved-card reference is absent from a route lookup.
- `api-gateway`: Maven test suite passed after adding the system-admin-only payment-gateway route and signed administrative context propagation.
- `driver-portal-android`: Kotlin debug compilation passed with JDK 21 after selected-card propagation.

## Next Safe Increment

Before enabling gateway enforcement in payment-service for a real provider,
complete provider-hosted/mobile tokenization and a real adapter. The canonical
charging-country source and pilot-scoped route guard are now implemented. The
legacy demo card model still has no provider-hosted payment token, so enabling
a live PSP route before tokenization would either break card charging or put
card data on an unsafe path.

The rollout sequence is therefore:

1. create the dedicated gateway service remote repository, image pipeline, and internal-only Kubernetes deployment;
2. configure one mock sandbox connection, merchant account, and route;
3. wire the feature-flagged route guard in shadow mode using the explicit pilot network;
4. add provider-hosted tokenization / certified terminal references;
5. enable enforcement only for the verified sandbox tenant;
6. retain Redis generation-checked cache invalidation for a multi-pod production rollout.
