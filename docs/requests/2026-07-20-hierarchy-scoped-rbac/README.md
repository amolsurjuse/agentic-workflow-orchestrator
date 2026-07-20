# Hierarchy-scoped RBAC and analytics isolation

## Request summary

ElectraHub must support small charge point operators using a strict ownership hierarchy:

```text
Enterprise -> Network -> Location -> Charger / connector -> Charging session
```

An administrator must only see, operate, or analyse the hierarchy branches explicitly granted to that administrator. A network operator must never be able to retrieve another network operator's chargers, sessions, dashboard data, or charging-success-rate (CSR) metrics. The design must remain low-latency at scale and avoid passing the complete user JWT through every service.

## Scope and decisions

| Area | Decision |
| --- | --- |
| Trust boundary | API gateway validates the user token and sends a short-lived, signed, compact access context downstream. Services do not receive the complete user JWT. |
| Scope cache | Gateway resolves an administrator's grants once, stores the compact scope in Redis for ten minutes, and reuses it by token identity. |
| Invalidation | Grant, role, or administrator changes invalidate the Redis scope directly after the transaction commits; a gateway endpoint is a safe fallback. |
| Authorization model | Every protected downstream query derives its scope from the signed context and fails closed when the context is missing, expired, malformed, or not permitted. |
| Data model | Locations, chargers, sessions, and analytics facts retain immutable ownership snapshots for enterprise, network, and location. This removes runtime hierarchy joins from high-volume paths. |
| Analytics | Dashboard, revenue, utilization, session search, and CSR queries add the resolved hierarchy predicate before pagination, aggregation, or Elasticsearch access. |
| Admin UI | System admins provision scoped administrators. Non-system admins receive only the permitted navigation, scope-aware filters, and aggregate data allowed for their role. |

## Role semantics

| Role | Managed scope | Ancestor visibility | Restrictions |
| --- | --- | --- | --- |
| `SYSTEM_ADMIN` | All hierarchy branches | Full | Only role that can access customer and administrator identity management. |
| `ENTERPRISE_ADMIN` | Granted enterprise and all descendants | Full within granted enterprise | Cannot access sibling enterprises. |
| `NETWORK_ADMIN` | Granted networks and all descendants | Parent enterprise read-only | Cannot modify enterprise configuration or access other networks. |
| `LOCATION_ADMIN` | Granted locations and all chargers/connectors beneath them | Network and enterprise read-only | Cannot modify parents or access sibling locations. |
| `ADMIN_READ_ONLY` | Explicit demo/assigned scope | Read-only | No customer identity, user management, or driver-level analytics. |

An administrator may hold more than one grant. Effective scope is the union of the grants, never an inferred broad tenant scope.

## Request path

1. The browser or admin client sends its normal access token only to the API gateway.
2. The gateway verifies authentication and the required broad API policy.
3. For an administrator, the gateway resolves a cache key from actor ID, JWT token version, and token ID. It reads a ten-minute Redis access-scope record.
4. On a cache miss, the gateway loads explicit grants from user-service and expands their descendant identifiers through charger-management-service. It writes the compact resolved scope to Redis.
5. The gateway adds a signed, short-lived `X-ElectraHub-Access-Context` header containing an opaque scope reference, actor identity, effective roles, issue/expiry times, and signature version.
6. Each downstream service verifies the signature and expiry, reads the scope reference, and applies it to repository and Elasticsearch predicates before fetching data.
7. User-service invalidates the cache after an access grant or administrator role changes. The next gateway request builds the new scope.

No client-controlled scope header is trusted. No service expands a client-provided enterprise, network, or location filter into a wider result set.

## Ownership snapshots and query performance

Hierarchy attributes are deliberately denormalized on operational and analytics records:

| Record | Stored ownership attributes |
| --- | --- |
| Location | Enterprise and network IDs/names as applicable |
| Charger/connector | Enterprise, network, and location IDs/names |
| Charging session | Enterprise, network, and location IDs/names captured at session creation |
| Billing/analytics fact | Enterprise, network, and location IDs captured with the fact |

Historic sessions and analytics facts are backfilled asynchronously in bounded batches with distributed Redis locks. New writes contain the snapshot at creation time. This guarantees that a later hierarchy rename or reassignment does not turn a historic billing record into an authorization leak.

High-volume list and analytics queries use ownership predicates and indexed fields, not chains of joins. Elasticsearch analytics use the same resolved scope filter. Pagination and aggregation occur only after the scope filter is applied.

## Service changes

| Repository | Responsibility |
| --- | --- |
| `api-gateway` | Resolves, caches, signs, and forwards compact administrator scope. |
| `user-service` | Stores access grants, provisions hierarchy-scoped admins, and invalidates cache after committed access changes. |
| `charger-management-service` | Resolves hierarchy ownership and enforces scoped charger, connector, and ancestor read/write operations. |
| `session-service` | Persists session ownership snapshots and provides scoped session querying. |
| `billing-service` | Persists/backfills analytics ownership snapshots and applies hierarchy scope to dashboard, revenue, utilization, and CSR queries. |
| `admin-portal-ui` | Provides scoped navigation, dashboard filters, CSR views, and system-admin-only grant provisioning. |
| `k8s-platform` | Supplies the required Redis and internal-service configuration to development and production workloads. |

## Security and failure behavior

- Missing, invalid, expired, or unsigned access context returns `403`; it never falls back to unscoped data.
- Cached access scope has a hard TTL. Access changes actively invalidate it; token version and token ID also prevent reuse across login/token changes.
- Descendant access is explicit after expansion. A location administrator can view ancestors but cannot write them.
- User and driver identity endpoints remain system-admin-only even if an admin can view aggregate sessions.
- Scope ownership is applied independently by each service so a gateway routing error or direct internal call cannot broaden visibility.
- Audit and operational telemetry record authorization failures without logging full credentials or signed context values.

## Rollout order

1. Deploy user-service, charger-management-service, session-service, and billing-service while existing stable replicas continue serving traffic.
2. Verify new pods are healthy, Redis connectivity is correct, and ownership backfills operate in bounded batches.
3. Deploy API gateway only after all consumers can validate the compact context.
4. Deploy admin portal last.
5. Validate system, enterprise, network, location, and read-only accounts against API and browser matrices.

The current rollout found a Kubernetes environment-variable collision: the service-injected `REDIS_PORT` can be a URL, while Spring expects a numeric port. Charger-management-service, session-service, and billing-service now use explicit `SPRING_DATA_REDIS_PORT` configuration with a numeric default. This is fixed at source before replacing the production charger pod.

## Validation matrix

| Check | Expected result |
| --- | --- |
| System admin hierarchy list | Can see all allowed resources and provision scoped admins. |
| Enterprise admin | Sees only granted enterprise, its networks, locations, chargers, sessions, dashboard, and CSR. |
| Network admin | Sees only granted networks/descendants; parent enterprise is read-only. |
| Location admin | Sees only granted locations/chargers/sessions/dashboard/CSR; ancestors read-only. |
| Cross-tenant direct API call | `403` or an empty scoped result; never another tenant's row. |
| Read-only demo admin | Can view assigned demo operational data but cannot access user data, driver analytics, or mutations. |
| Redis cache hit | Reuses compact scope without a grant expansion request. |
| Grant change | Cache invalidates and the next request reflects the new scope. |
| Historic session/fact | Backfill supplies ownership; records with unresolved ownership remain unavailable to scoped admins. |
| Performance | Scope predicate occurs before data loading; dashboard/CSR aggregates do not perform hierarchy join fan-out. |

## Status

- [x] Gateway compact signed scope cache and invalidation contract.
- [x] Scoped administrator provisioning and grant invalidation.
- [x] Charger, session, billing, analytics, and CSR scope enforcement.
- [x] Ownership snapshots and bounded historic backfills.
- [x] Admin portal scope-aware navigation, dashboard filters, CSR, and grant management.
- [x] Targeted backend Maven suites, portal production build, and Helm renders.
- [x] Production rollout completed at GitOps revision `402d2045f60ad547bdb3e45ce94e808e94cdecff`.
- [x] Production workloads verified healthy: user-service `43`, charger-management-service `22`, session-service `101`, billing-service `28`, API gateway `44`, and admin portal `48`.
- [x] Public production checks: `https://admin-portal.electrahub.net/` and `https://api.electrahub.net/actuator/health` returned `200` after rollout.
- [x] Confirmed the charger-management workload starts successfully even when Kubernetes injects the legacy URL-shaped `REDIS_PORT`; the explicit Spring port setting takes precedence.
- [ ] Perform the browser/API role matrix using pre-provisioned system, enterprise, network, location, and read-only administrator test accounts. No production administrator accounts were created or altered solely for this deployment check.
