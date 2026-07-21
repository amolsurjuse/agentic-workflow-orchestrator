# Payment Gateway Control Plane: Implementation Phase 2

Status: Implemented locally; deployment intentionally blocked until the
dedicated repository, image pipeline, and internal route are provisioned.

Date: 2026-07-21

## Boundary Created

The production gateway boundary is implemented as a new local service at:

```text
C:\development\project\payment-gateway-service
```

The expected remote repository
`git@github.com:amolsurjuse/payment-gateway-service.git` does not currently
exist. The service has therefore not been added to TeamCity, Argo CD, Kubernetes
or public API-gateway routing. This prevents a partially configured payment
component from changing existing driver payment behavior.

## Implemented Components

| Component | Implemented behavior |
| --- | --- |
| Provider-neutral adapter SPI | Isolates provider-specific API names and SDKs from payment/session logic. |
| Mock adapter | Deterministic sandbox approval, decline, customer-action, and timeout scenarios for regression and JMeter. It rejects production activation. |
| Gateway connection control plane | Draft, validate, activate, disable, safe connection metadata, capability summary, secret-reference flags, and immutable audit events. |
| Merchant account control plane | Network/enterprise-scoped merchant account metadata, country, settlement currency, and supported presentment currencies. |
| Payment route control plane | Capability-based routes keyed by merchant account, charging country, presentment currency, settlement currency, channel, and payment method. |
| Route policy | Fails closed for missing, disabled, inactive, time-invalid, unsupported-capability, or mock-production routes. |
| Gateway operation log | Provider operation idempotency, safe provider/public transaction references, failure code, and `PENDING_RECONCILIATION` state. |
| Recovery inquiry worker | Bounded scheduled provider-status inquiry for `PENDING_RECONCILIATION` records. It never replays an authorization, capture, void, or refund mutation. |
| Access boundaries | System-admin operations require a signed API-gateway access context. Internal mutations require an internal service credential. |
| Admin Portal | Feature-flagged system-admin gateway connection workspace. It never displays secrets; it accepts only vault/secret references. |

## Safety and Latency Decisions

1. The service records a gateway operation before invoking an adapter. A timeout
   is represented as `PENDING_RECONCILIATION`, not as a declined or released
   payment.
2. A bounded recovery worker performs status inquiry only. It preserves an
   unresolved timeout for later webhook/manual resolution rather than creating
   a second provider mutation.
3. Provider calls are outside database transactions. Database rows are updated
   before and after the call, so a long provider response cannot hold a database
   lock or transaction open.
4. Route resolution has a bounded ten-minute local cache and is invalidated on
   connection, merchant-account, or route changes. The new service is not
   permitted for multi-pod production routing until Redis-based cross-pod
   invalidation is added with the deployment slice.
5. The mock adapter is sandbox-only. A `MOCK` production connection cannot
   validate or activate.
6. Raw card-number-looking values are rejected at the gateway operation
   boundary. Only provider token, hosted checkout, or certified-terminal
   references can cross this boundary.
7. Secret values never enter the admin DTOs, operation records, audit records,
   response payloads, or logs. Only boolean configured-state and references
   stored inside the service are used.

## Current API Surface

Administrative APIs, signed system-admin context required:

```text
GET  /api/v1/gateway/admin/connections
POST /api/v1/gateway/admin/connections
POST /api/v1/gateway/admin/connections/{id}/validate
POST /api/v1/gateway/admin/connections/{id}/activate
POST /api/v1/gateway/admin/connections/{id}/disable

GET  /api/v1/gateway/admin/merchant-accounts
POST /api/v1/gateway/admin/merchant-accounts
GET  /api/v1/gateway/admin/routes
POST /api/v1/gateway/admin/routes
```

Internal APIs, internal-service credential required:

```text
POST /api/v1/gateway/internal/routes/resolve
POST /api/v1/gateway/internal/operations
```

## Verification Completed

| Check | Result |
| --- | --- |
| Java 21 production compile | Passed |
| Gateway route policy tests | Passed |
| Mock adapter scenario tests | Passed |
| Admin Portal TypeScript production build | Passed |

## Next Safe Step

1. Provision `payment-gateway-service` as a GitHub repository and add its
   TeamCity build, container registry, Helm values, Argo CD application,
   service-to-service credential secret, and API gateway route.
2. Add Redis pub/sub configuration-version invalidation before enabling more
   than one gateway pod.
3. Connect `payment-service` to the internal route/operation APIs only after
   session context supplies merchant account, charging country, settlement
   currency, channel, and provider token reference.
4. Add a provider sandbox adapter (Stripe or Mollie for the Netherlands
   pilot), webhook verification, inquiry/retry worker, and the remaining
   merchant/route admin forms.
