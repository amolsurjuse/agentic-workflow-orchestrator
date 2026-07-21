# Implementation Phase 4: Runtime Safety, Gateway Access, And Cache Coherency

Date: 2026-07-21

## Outcome

The payment gateway control plane is now wired into the application boundary
without exposing provider-operation APIs to browsers. It remains disabled for
financial enforcement until a tokenized provider sandbox is available.

## Public And Internal API Boundary

The API gateway now knows the `payment-gateway` route:

```text
https://api.electrahub.net/payment-gateway/api/v1/gateway/admin/*
  -> payment-gateway-service /api/v1/gateway/admin/*
```

Only `SYSTEM_ADMIN` can access this route. The API gateway resolves and signs a
short-lived administrative access context before forwarding the request. The
new service independently verifies that signature and requires
`systemAdmin=true`.

The following internal endpoints are intentionally not granted a public API
gateway policy:

```text
/api/v1/gateway/internal/routes/resolve
/api/v1/gateway/internal/routes/resolve-by-scope
/api/v1/gateway/internal/operations
```

They are reachable only through the Kubernetes service address and require the
shared `X-ElectraHub-Internal-Key` credential. The payment-service guard sends
that exact header. Its configuration resolves in this order:

```text
PAYMENT_GATEWAY_INTERNAL_TOKEN
APP_INTERNAL_SERVICE_KEY
APP_SECURITY_INTERNAL_TOKEN
```

The fallback retains compatibility with the existing cluster internal-service
secret while allowing a dedicated gateway credential during rollout.

## Route Cache Coherency

Payment route resolution is start-path work, not meter-value work. A small
local cache prevents repeated SQL joins for the same eligible route. Each
lookup verifies one Redis generation counter first:

```text
Redis generation readable + unchanged -> use local approved route
Redis generation changed -> evict local route and resolve from PostgreSQL
Redis unavailable -> bypass local route and resolve from PostgreSQL
```

Every connection, merchant-account, or payment-route mutation clears the
current pod cache and increments the shared Redis generation. This gives all
pods deterministic invalidation without relying on best-effort pub/sub.

The Redis connect timeout defaults to 200 ms. A cache infrastructure failure
therefore adds a bounded read-through query rather than returning an obsolete
provider route or blocking an entire charging start indefinitely.

## Operation Idempotency

The gateway service now records the initial durable operation state with
`PENDING_RECONCILIATION` as both status and result code. A concurrent retry
therefore receives a truthful pending result rather than an accidental
`APPROVED` code.

Provider execution is still outside database transactions. The gateway creates
the idempotent operation record first, invokes the adapter, and then persists
the result. A timeout remains pending and recovery performs only a provider
status inquiry; it never repeats a financial mutation blindly.

### Multi-Replica Recovery Control

Timed-out provider operations now use a PostgreSQL recovery lease rather than
allowing every gateway replica to poll the same operation. An atomic
`FOR UPDATE SKIP LOCKED` claim increments a durable attempt count and grants a
45-second lease. Non-terminal inquiries are rescheduled using bounded
exponential backoff (30 seconds, 1 minute, 2 minutes, and so on, capped at 30
minutes). Terminal results clear the lease and retry metadata.

This reduces provider load during outages, prevents recovery thundering herds,
and keeps the unknown-outcome rule intact: recovery only asks the provider for
status and never repeats an authorization, capture, void, or refund mutation.

## Validation

Completed locally with JDK 21:

| Area | Validation |
| --- | --- |
| payment-gateway-service | Maven tests, including cross-pod generation invalidation and Redis-unavailable cache bypass |
| payment-service | Maven tests, including an HTTP contract test for the internal header and no saved-card reference in route lookup payload |
| session-service | Maven tests |
| charger-management-service | Maven tests |
| api-gateway | Maven tests, including signed scope for the payment-gateway admin path and exclusion of its internal path |
| admin-portal-ui | TypeScript and Vite production build |
| Android Driver Portal | Kotlin debug compilation |

## Deployment And Live-PSP Blockers

These are deliberate blockers, not failures to be bypassed:

1. `payment-gateway-service` has no configured GitHub remote or TeamCity image
   pipeline. Its intended GitHub repository does not currently exist.
2. The service has no Kubernetes/Argo application yet. It must receive only
   cluster-internal service exposure, PostgreSQL schema migration access,
   Redis access, and the shared internal-service secret.
3. No selected provider sandbox account, secret reference, webhook secret, or
   PSP adapter is present. `MOCK` is valid only for regression/demo use and is
   prohibited for production money movement.
4. The current mobile card flow still creates local demo card aliases. A real
   route requires provider-hosted mobile/web tokenization or a certified
   terminal reference; raw PAN/CVV must never be passed to the new gateway.
5. Financial execution, provider webhook verification, capture, void, refund,
   and reconciliation must be enabled only after the selected sandbox flow has
   been exercised end to end.

## Internal Deployment Shape Prepared

`k8s-platform` now contains the Helm values/configuration skeleton for
`payment-gateway-service` in both dev and prod. It intentionally has **no
Argo CD Application** yet, because the service does not have a remote source
repository, image tag, or CI build configuration. Adding an Argo application
now would continuously attempt to deploy a nonexistent image.

The prepared configuration provides:

- A ClusterIP-only service on port `8098`; no ingress is created.
- PostgreSQL `appdb` access with a separate `payment_gateway` schema managed
  by Liquibase, avoiding an unprovisioned standalone database dependency.
- Redis with a bounded 200 ms connection timeout for route-cache generation.
- Shared internal-service and signed admin-context secrets sourced from
  Kubernetes secrets, never ConfigMaps.
- Production defaults that disable the mock adapter and all production-money
  execution. The deployment alone cannot activate a real payment route.
- Fixed resource and health-probe defaults appropriate for a low-volume
  control-plane service. Horizontal scaling is deferred until the image and
  provider traffic profile are known.

## Next Implementation Sequence

1. Create the remote repository and CI image pipeline for
   `payment-gateway-service`.
2. Add its internal-only Helm/Argo deployment configuration with feature flags
   off by default.
3. Select one sandbox PSP and implement its isolated adapter plus provider
   contract tests.
4. Replace demo card entry with provider tokenization and store only a provider
   payment-method alias.
5. Add the durable provider authorization, capture, void, refund, webhook,
   and reconciliation links to `payment-service`.
6. Enable shadow routing for one explicit pilot network, then sandbox
   enforcement, and only then live money movement after legal/commercial
   approval.
