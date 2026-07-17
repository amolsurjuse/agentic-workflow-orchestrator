# Data-Level RBAC and Scope-Aware Operations Dashboard Plan

**Date:** 2026-07-17
**Status:** Planning only. No application behavior has been changed.
**Objective:** Make ElectraHub safe for multiple micro charge point operators (CPOs). A platform administrator can create an enterprise, its networks, locations, chargers, and delegated operators. Every administrator must see and operate only the resources explicitly within their assigned hierarchy. The same server-enforced scope must drive operational dashboards and Charging Start Success Rate (CSR) reporting.

## Executive Decision

The implementation must use **data-level authorization**, not hidden navigation or client-supplied filters.

The canonical operational hierarchy is:

```text
ElectraHub platform
  -> Enterprise (the contractual CPO tenant)
    -> Network
      -> Location
        -> Charger
          -> EVSE
            -> Connector
```

`Enterprise` is the tenant boundary. `Network` is a delegated operational boundary under an enterprise. A user can hold one or more grants at any allowed root in this tree; effective access is the union of those roots and their descendants. A network administrator cannot see a sibling network, another enterprise, or data outside an explicit additional grant.

This plan deliberately does not put a large list of permitted resource IDs into a client JWT. Scope is evaluated and enforced server-side, cached safely, and pushed into each data query or event projection.

## Why the Current Implementation Is Not Sufficient

| Current evidence | Risk | Required change |
| --- | --- | --- |
| `auth-service` JWT contains user ID, token version, and role names only. | Roles cannot say which enterprise, network, or location is permitted. | Add versioned resource grants and a server-side effective-scope resolver. |
| `user-service` `AuthenticatedUser` contains only ID, email, and roles. | Service methods cannot apply a resource predicate. | Propagate a verified access context and enforce it in every administrative service. |
| `charger-management-service` already models Enterprise -> Network -> Location -> Charger, but list and mutation APIs accept client filters without scope enforcement. | A role allowed through the gateway can enumerate or mutate another CPO's assets. | Make this hierarchy the authoritative ownership catalog and apply scope predicates to all inventory APIs and OCPP commands. |
| `session-service` persists `locationId` but not enterprise/network ownership snapshots. Its admin search accepts optional filters. | Session search, receipt access, and remote stop cannot safely enforce enterprise/network visibility. | Store an immutable ownership snapshot on every session and enforce it in the repository query. |
| `billing-service` analytics documents contain `locationId` and `chargerId`, but not enterprise/network fields. | Dashboard and exports can only filter by client-provided location and cannot aggregate safely by hierarchy. | Enrich analytics facts with scope dimensions at event ingestion and query only authorized dimensions. |
| Existing gateway policy is route-and-role based. Some downstream services currently permit `/api/v1/**` internally. | A path rule is a coarse gate, not a data boundary; direct service exposure or a future route can bypass intended isolation. | Keep coarse gateway RBAC, add service-side scope checks, and restrict service ingress to trusted gateway/internal callers. |
| The admin portal sidebar checks broad read-only status only. | Hiding a menu cannot protect APIs or prevent indirect data leakage through dropdowns, totals, exports, or errors. | Drive navigation and selectable scope from an access-context API, while treating the UI as convenience only. |

Relevant current source includes:

- `auth-service/.../JwtService.java`
- `user-service/.../AuthenticatedUser.java` and `AdminUserController.java`
- `charger-management-service/.../ChargerAdminController.java`, `ChargerAdminService.java`, and `ChargerAdminRepository.java`
- `session-service/.../ChargingSessionController.java`, `ChargingSessionService.java`, and `ChargingSessionRepository.java`
- `billing-service/.../AdminAnalyticsController.java` and `ChargingAnalyticsElasticsearchService.java`
- `admin-portal-ui/src/api/chargerManagement.ts`, `sessions.ts`, `analytics.ts`, and `components/shared/Sidebar.tsx`

## Security Invariants

These rules are mandatory implementation constraints.

1. A request must be denied by default when no active grant covers the target resource.
2. A client filter can narrow an authorized result but can never broaden it.
3. Direct-resource reads outside a caller's scope return `404` to avoid resource enumeration. Mutations return `403` and create an audit record.
4. List endpoints return only authorized rows and never expose unauthorized totals, autocomplete values, chart counts, export metadata, or error details.
5. All asynchronous events, Elasticsearch documents, Redis state, downloads, and caches carry the same ownership dimensions as the source operation.
6. Scope revocation invalidates effective-access caches immediately. A revoked user must not retain access until the access-token expiry.
7. Historical sessions remain attributed to the ownership path at session start. Moving a location or charger later must not transfer historical revenue, CSR, or driver data to another CPO.
8. `SYSTEM_ADMIN` is the only cross-enterprise role. It must be explicitly assigned, audited, and never inferred from a tenant-level role.
9. UI visibility is not authorization. Every backend action must independently enforce the invariant.
10. Driver PII, payment details, and exports have separate permissions from operational charger visibility.

## Target Administrator Model

### Roles

| Role | Grant root | Intended capability | Explicit limits |
| --- | --- | --- | --- |
| `SYSTEM_ADMIN` | Platform | Create enterprises, administer platform policy, view all tenants, assign any grant, execute platform support actions. | Must be rare; no implicit assignment from any CPO role. |
| `ENTERPRISE_ADMIN` | One enterprise | Manage the enterprise, all descendant networks/locations/assets, enterprise dashboards, approved commercial configuration, and delegated lower-level staff. | Cannot access other enterprises or platform-wide user records. |
| `NETWORK_ADMIN` | One network | Manage assigned network and descendant locations/assets; view network dashboard, sessions, health, and approved pricing/configuration. | Cannot access sibling networks, parent enterprise configuration, or other enterprises. |
| `LOCATION_OPERATOR` | One location | Monitor local charger/connector health, active sessions, alarms, configuration allowed by policy, and remote operational actions such as a documented remote stop. | Cannot change enterprise/network structure, access another location, or view unneeded driver/payment PII. |
| `LOCATION_VIEWER` | One location | Read-only operational dashboard, charger state, and aggregate session/CSR metrics. | Cannot issue commands, export data, or see driver details. |
| `SUPPORT_OPERATOR` | Explicit, time-bound support grant | Troubleshoot a specified enterprise/network/location with audited reason and expiry. | No permanent broad support access; no PII or payment data unless a separately approved permission exists. |

Initial delivery should keep `SYSTEM_ADMIN` as the only role that can create or change administrative grants. Once the audit trail and escalation controls are proven, an `ENTERPRISE_ADMIN` may be allowed to invite only lower-privilege roles within its own descendants.

### Permission Families

Roles map to permission families rather than a growing collection of route rules:

- `HIERARCHY_READ`, `HIERARCHY_MANAGE`
- `CHARGER_READ`, `CHARGER_MANAGE`, `CHARGER_COMMAND`, `CHARGER_CERTIFICATE_MANAGE`
- `SESSION_READ`, `SESSION_STOP`, `RECEIPT_READ`
- `DASHBOARD_READ`, `CSR_READ`, `REPORT_EXPORT`
- `PRICING_READ`, `PRICING_MANAGE`, `SUBSCRIPTION_MANAGE`
- `DRIVER_AGGREGATE_READ`, `DRIVER_PII_READ`
- `ADMIN_GRANT_MANAGE`, `AUDIT_LOG_READ`

For the first release, a location operator should receive operational permissions only. It should not obtain `DRIVER_PII_READ`, raw card data, full wallet data, or unrestricted user directory access. Receipts should be masked according to the role's data policy.

### Grant Semantics

Create a grant per administrator, role, and hierarchy root. A person may have multiple grants, for example, Network A administrator plus Location B viewer.

Suggested `admin_access_grant` fields:

| Field | Purpose |
| --- | --- |
| `grant_id` | Stable audit identifier. |
| `principal_user_id` | Existing user-service identity. |
| `role_code` | One of the approved operational roles. |
| `scope_type`, `scope_id` | `PLATFORM`, `ENTERPRISE`, `NETWORK`, or `LOCATION` root. |
| `state`, `valid_from`, `valid_until` | Active, revoked, expired, or pending invitation lifecycle. |
| `grant_version` | Monotonically increasing version for invalidation. |
| `created_by`, `revoked_by`, `reason`, timestamps | Mandatory auditability. |
| `delegation_depth` | Enforces that a delegated user cannot grant a higher level than permitted. |

Constraints:

- unique active grant for `(principal_user_id, role_code, scope_type, scope_id)`;
- a non-system actor may grant only a role lower than their delegable role and only within a descendant of an active grant;
- no self-escalation, self-approval, or removal of the final active enterprise administrator;
- system administrators use an invitation/approval flow for another system administrator;
- inactive enterprise/network/location automatically makes descendant grants non-operational;
- revoking a grant increments the principal authorization version and terminates active admin sessions where feasible.

### Invitation and Provisioning Flow

1. A system administrator creates the enterprise.
2. The system administrator creates its network(s), location(s), and initial enterprise administrator grant.
3. The administrator sends an invitation to an existing verified account or a new email address. Do not create a shared password or transmit credentials in email.
4. The invitee verifies identity, accepts the grant, and receives a fresh token with the new authorization version.
5. The grant appears in an administrative audit trail with its hierarchy root, role, issuer, validity, and reason.
6. Grant updates, expiry, and revocation publish invalidation events to gateway and service caches.

## Ownership Source and Data Model

### Canonical Ownership Catalog

Use the charger-management inventory as the operational ownership source because it already stores and returns:

```text
enterprise_id -> network_id -> location_id -> charger_id -> evse_id -> connector_id
```

Do not make the separate station-management `Organization` and `Location` model an additional security source. During discovery, reconcile it to the canonical inventory using explicit mappings. A resource that cannot be mapped is **unassigned** and is invisible to tenant administrators until a system administrator assigns it.

Create a versioned `resource_scope_registry` projection in the authorization domain:

| Field | Purpose |
| --- | --- |
| `resource_type`, `resource_id` | Resource identity. |
| `enterprise_id`, `network_id`, `location_id` | Denormalized ownership path for fast predicates. |
| `parent_type`, `parent_id` | Validates tree changes. |
| `scope_version` | Increments on any ownership transition. |
| `state` | Active, inactive, decommissioned, or unassigned. |
| timestamps and event sequence | Enables reconciliation and idempotent projection. |

Charger-management remains authoritative and publishes an outbox event whenever hierarchy ownership changes. The authorization projection, session service, billing analytics, OCPP command layer, and search projections consume that event idempotently.

### Immutable Operational Snapshots

Avoid a cross-service hierarchy lookup for every session or dashboard row.

At charging-start acceptance, resolve the connector's ownership once and persist an immutable snapshot on the session/attempt:

```text
enterprise_id
network_id
location_id
charger_id
evse_id
connector_id / connector_ref
ownership_scope_version
```

Apply the same snapshot to:

- charging session and receipt records;
- charging attempt/CSR records;
- current-session Elasticsearch documents;
- billing receipt analytics documents;
- notifications and audit events that refer to an asset;
- Redis connector/session state used for live dashboards;
- OCPP command audit entries.

For active sessions, prevent cross-tenant re-parenting of the location/charger. For completed sessions, preserve the start-time ownership snapshot even when the live asset later moves.

## Authorization Architecture

### Request Flow

```text
Admin portal
  -> API gateway authenticates JWT and applies coarse route permission
  -> authorization resolver obtains effective grant roots for principal + authorization version
  -> gateway/service creates a short-lived, signed internal access context
  -> target service validates the context and converts it to a ScopePredicate
  -> repository, Elasticsearch query, command target, or export query applies ScopePredicate
  -> response contains only authorized data
```

The access token should contain only stable identity claims, global role hints, and `authorizationVersion`. It must not contain a potentially large list of location IDs. The server-side resolver is the source of truth.

### Effective Scope Resolution

1. `user-service` owns identities, grants, authorization versions, and audit entries.
2. It maintains a read projection of resource ownership from charger-management events.
3. It resolves an `EffectiveAdminScope`: platform flag plus allowed enterprise, network, and location roots grouped by permission family.
4. Redis caches the resolved scope by `(principalUserId, authorizationVersion)` for a short TTL. Grant/hierarchy events explicitly evict the cache; TTL is only a backup.
5. The gateway resolves scope at most once per request and passes a signed, short-lived internal access assertion. No public caller may supply trusted access headers.
6. Each downstream service validates the internal assertion and has a local `ScopePredicate` adapter. If the assertion is absent, expired, invalid, or cannot be resolved, the service fails closed.

This keeps one authorization resolution off the hot data loop. Repository queries receive a compact predicate such as:

```text
enterprise_id IN permittedEnterpriseRoots
OR network_id IN permittedNetworkRoots
OR location_id IN permittedLocationRoots
```

For CPOs with a very large number of explicit location grants, use a materialized authorization relation or Elasticsearch terms-lookup document rather than emitting thousands of IDs in every query. Benchmark this threshold before launch; do not guess it.

### Service-Side Enforcement

Every administrative operation must call a shared `AdminScopeAuthorizer` before reading or changing data. It must cover:

| Domain | Examples that must be scope checked |
| --- | --- |
| Hierarchy | List/create/update/disable enterprise, network, location, charger, EVSE, connector. Parent IDs in request bodies are targets, not trusted selectors. |
| Charger operations | Configuration, certificate management, reset, change availability, diagnostics, remote start/stop, status requests, firmware commands, decommission. |
| Sessions | Search, counts, active sessions, session detail, receipt, remote stop, exports, and SSE/admin live feeds. |
| Analytics | All dashboard cards, trends, connector counts, utilization, user aggregates, report jobs, report download, and reindex/sync triggers. |
| Pricing and subscriptions | Plans, tariffs, allocations, utilization, and any tenant-scoped benefit configuration. |
| Notifications and audit | Inbox results, alert subscriptions, audit searches, and acknowledgements. |
| Search/indexes | Charger autocomplete, connector search, Elasticsearch queries, CSV/PDF exports, cached result keys, and background report jobs. |

Use no post-query filtering. The predicate must be part of SQL/Elasticsearch query construction. For a direct target lookup, authorize the resource path before returning any body or forwarding any OCPP command.

### Gateway and Network Hardening

Current gateway RBAC remains useful as the first coarse gate, but it cannot be the only gate.

- Change downstream admin endpoints from broad `permitAll()` behavior to require a verified internal service/gateway identity plus scope assertion.
- In Kubernetes, expose admin service ports only to the API gateway and required internal callers using NetworkPolicies. Do not publish service ingresses that bypass the gateway.
- Use mTLS or workload identity for gateway-to-service traffic. An internal shared header alone is not enough.
- Strip caller-supplied identity/scope headers at the gateway before adding its own signed context.
- Require idempotency and an audit reason for dangerous commands such as remote stop, reset, decommission, certificate change, and status change.

## Admin Portal Experience

### Access Context and Navigation

Add `GET /api/v1/admin/access-context`. It returns only the signed-in administrator's permitted hierarchy tree, permission families, default context, and whether they may switch among multiple grants.

The portal should:

- default an enterprise administrator to its enterprise, a network administrator to its network, and a location user to its location;
- show a context breadcrumb such as `Enterprise / Network / Location` rather than a global data selector;
- show only authorized descendants in all search, parent, filter, and creation controls;
- hide unavailable actions based on permissions, but rely on the API for enforcement;
- remove platform-level navigation for tenant users;
- avoid a global user-directory page for tenant roles; provide aggregate driver metrics only unless a separate PII policy permits more;
- use a clear empty state for an administrator with no active grant, not a global fallback list.

### Management Rules in the UI

- A network administrator may create a location only under their network. The parent is preselected and locked when there is one possible parent.
- A location operator may not reassign a charger to another location.
- A user with two grants may switch only among those roots. Results always use the selected authorized context intersected with effective scope.
- Existing generic role labels (`NETWORK`, `ENTERPRISE`, `LOCATION`, `SITE`, `ADMIN_READ_ONLY`) should not be presented as sufficient access. Show the new role and its explicit scope.
- Each administrator detail view must display active grants, hierarchy root, expiry, issuer, and audit history.

## Scope-Aware Operations Dashboard

### Dashboard Contract

Replace client-selected `locationId` filtering as the security mechanism with an authorized context parameter:

```text
GET /api/v1/admin/dashboard/overview?focusType=NETWORK&focusId=NW-...
```

The server validates that `focusType/focusId` is covered by the caller's effective scope. It derives all child filters itself. A location operator cannot request an enterprise focus even if they alter the browser request.

Expose a small, composable API surface:

- `GET /admin/access-context`
- `GET /admin/dashboard/overview`
- `GET /admin/dashboard/connector-health`
- `GET /admin/dashboard/active-sessions`
- `GET /admin/dashboard/utilization`
- `GET /admin/dashboard/csr`
- `GET /admin/dashboard/alerts`
- `POST /admin/reports` and `GET /admin/reports/{id}` only when the report's stored scope is still authorized at download time.

### What Each Scope Sees

| Scope | Dashboard behavior |
| --- | --- |
| Platform system admin | All enterprises, optional enterprise comparison, platform health, and carefully controlled support data. |
| Enterprise admin | All networks and locations within that enterprise; weighted enterprise rollups and drill-down only to descendants. |
| Network admin | Only its locations/assets; network rollups and location/charger drill-down. |
| Location operator/viewer | One location's connector health, active sessions, local alerts, utilization, cost/energy summary according to permission, and location CSR. |

### Dashboard Read Models

Separate live operations from historical analytics:

1. **Operational state projection:** connector status, last heartbeat, active session count, fault count, power, and active alerts. Updated from OCPP/session events and stored in Redis plus a durable projection. Scope fields are present on every row.
2. **Historical fact projection:** completed sessions, energy, tariff/cost, tax, stop reason, and ownership snapshot. Stored in Elasticsearch and/or optimized reporting tables with enterprise/network/location fields.
3. **CSR attempt projection:** all charge-start attempts, including failures that never become sessions. It has immutable scope fields and finalized outcome classification.
4. **Rollups:** daily/hourly facts by enterprise, network, location, charger, and connector. Rollups are computed from facts, never by averaging child percentages.

The dashboard can combine a short-lived live-state query with pre-aggregated historical metrics. It must not scan raw charging sessions or call each charger synchronously to render a page.

### Dashboard Metrics

Operational metrics:

- connectors by `AVAILABLE`, `CHARGING`, `SUSPENDED/IDLE`, `FAULTED`, `UNAVAILABLE`, `OFFLINE`;
- active sessions, idle sessions, oldest active/idle duration, and unresolved alerts;
- heartbeat freshness, command success/failure, and charger health;
- utilization, delivered energy, completed session count, and time trends.

Commercial metrics, only for roles that have permission:

- charging, idle, tax, discount, and total amounts with currency isolation;
- receipts/settlement state and export readiness;
- no cross-currency sum without an explicit reporting-currency/FX policy.

Driver metrics:

- unique drivers and aggregate retention only where `DRIVER_AGGREGATE_READ` is granted;
- no full name, email, wallet, card, or user-level history on location dashboards by default.

## CSR Design

### Definition

For ElectraHub, CSR should mean **Charging Start Success Rate**, not generic session completion:

```text
CSR = successful eligible charging-start attempts / all eligible charging-start attempts * 100
```

A successful attempt reaches an OCPP-confirmed charging/transaction-start state and receives the expected first meter/status confirmation inside a configurable time window. A completed session is not required for success because a driver may legitimately stop charging after it began.

Business exclusions agreed for the product must be explicit:

- manual driver cancellation is excluded;
- failure caused by the driver's own card/payment instrument is excluded;
- a hardware, OCPP, platform, authorization, or payment-integration failure after a valid customer attempt remains visible and is classified accurately;
- a later idle, unplug, low-balance stop, or normal driver stop does not retroactively turn a successfully started session into a CSR failure.

Show both raw operational outcomes and the business CSR with an exclusion breakdown. Never hide exclusions in a single percentage.

### Charging Attempt State Machine

Create a `charging_attempt` in session-service before remote start or authorization is sent:

```text
REQUESTED
  -> PAYMENT_OR_AUTHORIZED
  -> COMMAND_ACCEPTED
  -> CHARGING_CONFIRMED                 = success
  -> FAILED_FINAL                       = eligible failure or documented exclusion
  -> CANCELLED_BY_DRIVER                = excluded
  -> EXPIRED_WAITING_FOR_CHARGER        = eligible failure
```

Store:

- attempt ID and idempotency key;
- actor/channel/auth method/payment method;
- immutable ownership snapshot;
- request, authorization, command, and confirmation timestamps;
- outcome, normalized failure reason, responsibility category, eligibility flag, and rule version;
- links to session, OCPP transaction, payment authorization, and correlation/trace IDs.

The lifecycle must be emitted through an outbox/Kafka event. The analytics projection consumes it idempotently. A finalizer marks attempts as timed out only after the defined confirmation window, avoiding premature failures from asynchronous OCPP behavior.

### CSR Reporting Rules

- Calculate hierarchy rollups from summed `eligible_attempts` and `successful_attempts`, never the arithmetic average of child CSR percentages.
- Return numerator, denominator, percentage, exclusion count, failure categories, measurement window, and freshness timestamp.
- Label an attempt as provisional until finalized; do not mix it into a finalized historical CSR silently.
- Support drill-down: enterprise -> network -> location -> charger -> connector, constrained by authorization.
- Require a minimum sample-size disclosure; a 100 percent result from one attempt must not be presented as a reliable operational conclusion.
- Keep raw fact retention and aggregate retention separately according to the eventual privacy/contract policy.

## Service-by-Service Delivery Scope

| Component | Required work |
| --- | --- |
| `user-service` | Add administrative grant entities, invite workflow, effective scope resolver, authorization versioning, grant/audit APIs, resource-scope projection consumer, and cache invalidation events. |
| `auth-service` | Include authorization version in tokens; refresh/revoke tokens after grant changes. Do not add long scope lists to JWTs. |
| `api-gateway` | Keep route permission checks, resolve effective scope once, inject signed internal context, strip spoofed headers, and add authorization audit correlation. |
| `charger-management-service` | Declare canonical ownership catalog, enforce scope on every list/mutation/command, publish ownership change events, prevent unsafe re-parenting, and add ownership indexes. |
| `session-service` | Add ownership snapshots to sessions, enforce scope on search/detail/receipt/stop/live streams, create `charging_attempt`, publish lifecycle events, and attach outcome reasons. |
| `billing-service` | Enrich Elasticsearch/report facts with enterprise/network/location scope, filter all queries/exports server-side, create CSR fact/rollup projections, and protect report downloads after scope changes. |
| `ocpp-service` | Require scope authorization before administrative charger commands; include immutable resource context in command/result events and audit them. |
| `notification-service` | Scope administrative alert streams and prevent cross-tenant recipient lookup or alert browsing. |
| `admin-portal-ui` | Consume access context, render only permitted navigation/actions/focus tree, add grant management, context breadcrumbs, scoped dashboard, CSR drill-down, and accessible empty/denied states. |
| Platform/Kubernetes | Make services private behind gateway/internal identity, add NetworkPolicies, mTLS/workload identity, monitoring, cache-health alerts, and feature-flag deployment controls. |

## Delivery Phases

### Phase 0: Decisions, Inventory, and Baselines

1. Approve terminology: `Enterprise` is CPO tenant; `Network` is a child operational scope; `Location` is the smallest initial delegated root.
2. Produce an endpoint inventory for all admin routes, background jobs, report downloads, GraphQL/search endpoints, OCPP commands, SSE streams, and cache keys.
3. Reconcile existing charger-management hierarchy data with station-management data; identify orphans, duplicate IDs, and unmapped assets.
4. Define role-to-permission matrix, PII policy, dangerous command policy, CSR reason taxonomy, confirmation window, and exclusion rules.
5. Record current latency/throughput baselines for key lists, dashboard calls, session search, connector status, and command execution.

**Exit criteria:** approved data model and policy decisions; no automated broad role migration; a verified map from each existing charger/session/analytics fact to one enterprise/network/location or an explicit unassigned queue.

### Phase 1: Authorization Foundation

1. Add grants, authorization version, invitation status, and audit tables in user-service.
2. Add resource-scope registry projection and outbox/event contracts from charger-management.
3. Implement effective scope resolver and Redis cache with explicit invalidation.
4. Add signed internal access context and validation library for Java services.
5. Modify JWT/session refresh handling for authorization-version changes.
6. Add permission family policy and block unsupported legacy generic roles from authorizing tenant data.

**Exit criteria:** a system administrator can invite an enterprise/network/location administrator; revocation takes effect immediately in gateway and service tests; no scope list is embedded in a browser-controlled claim.

### Phase 2: Enforce Scope on Operational Data

1. Enforce hierarchy predicates in charger-management repositories and command routes.
2. Add immutable ownership columns to sessions and current-session documents; backfill from canonical inventory.
3. Enforce scope on session search, receipt, remote stop, and live admin feeds.
4. Enrich billing analytics documents and report jobs with ownership fields and request scope snapshots.
5. Enforce scope on pricing, subscriptions, notifications, audit logs, connector search, and all exports.
6. Lock cross-tenant resource moves behind a system-admin workflow; prohibit moving assets with active sessions.

**Exit criteria:** a location administrator cannot retrieve, count, stop, export, search, subscribe to, or infer any sibling/foreign network resource through any API path.

### Phase 3: Dashboard and CSR Read Models

1. Create operational state, historical session, and charging-attempt projections with hierarchy dimensions.
2. Add `charging_attempt` lifecycle and finalizer in session-service.
3. Implement CSR rollups and explanation API with failure/exclusion categories.
4. Add scoped dashboard API endpoints that derive scope on the server.
5. Implement report-scope persistence and re-check authorization when a report is downloaded.

**Exit criteria:** an enterprise, network, and location dashboard return weighted, consistent metrics; no query scans unbounded historical facts for a normal dashboard load.

### Phase 4: Portal Experience

1. Add access-context bootstrap and scoped navigation.
2. Add system-administrator grant/invitation management with immutable audit timeline.
3. Replace global filters with authorized context picker and breadcrumbs.
4. Add role-appropriate dashboard cards, CSR chart, drill-down, data freshness, and explanation states.
5. Restrict PII/reporting controls based on permission family.

**Exit criteria:** users cannot select out-of-scope parent/child resources in the UI, and the portal remains useful for a location-only operator without empty global pages.

### Phase 5: Security, Performance, and Controlled Rollout

1. Run negative authorization tests across every endpoint and async consumer.
2. Load test scoped dashboard, session list, live status, CSR aggregation, and cache invalidation.
3. Enable in shadow mode for system administrators, compare legacy/global vs scoped results, and reconcile discrepancies.
4. Explicitly map each existing non-system admin to grants. Users without approved mapping remain denied, never global.
5. Enable one pilot enterprise at a time; monitor denied-scope anomalies, cache hit rate, query latency, and event-projection lag.

**Exit criteria:** pilot tenant isolation is independently verified, security review is signed off, and production dashboards meet agreed latency/freshness budgets.

## Performance and Reliability Guardrails

| Risk | Design control |
| --- | --- |
| Authorization call on every row | Resolve scope once per request; pass a compact predicate into SQL/Elasticsearch queries. |
| Stale scope after revocation | Authorization version plus event-driven Redis invalidation; fail closed on cache/context inconsistency. |
| Large hierarchy expansion | Filter at the highest permitted root when possible; use materialized relations/terms lookup for many explicit location grants. |
| Dashboard scans | Use event-driven facts and hourly/daily rollups, not raw session scans or synchronous charger fan-out. |
| Slow live status | Keep a scope-stamped connector-state projection keyed by resource hierarchy; batch query by scope. |
| Cross-tenant cache collision | Include tenant/scope version and authorization context in every cache key; never cache a global result under a caller-neutral key. |
| Report leak after revocation | Persist report scope and re-authorize at both status and download time. |
| Re-parenting causes historical reassignment | Immutable ownership snapshots; prohibit moves with active sessions; system-admin workflow only. |
| Event delay | Idempotent outbox events, sequence/version checks, reconciliation job, freshness timestamp, and dashboard stale-data indicator. |

Initial performance acceptance targets must be baselined before coding. At minimum, the scope design must add no per-row remote calls, no unbounded hierarchy expansion, and no more than one cached scope resolution per normal request. Dashboard reads should be backed by projections and remain within the agreed p95 latency under the pilot fleet/load dataset.

## Test Plan and Release Gates

### Authorization Matrix

Create at least two enterprises, two networks per enterprise, two locations per network, and representative chargers/sessions/receipts/analytics documents. Assert all of the following:

- enterprise A administrator cannot list or retrieve enterprise B resources;
- network A administrator cannot retrieve sibling network B assets or totals;
- location A operator cannot see another location in the same network;
- a user with two grants sees only the union of those grants;
- direct ID guessing returns no data and cannot execute a command;
- server rejects manipulated `enterpriseId`, `networkId`, `locationId`, export URL, report ID, or dashboard focus parameter;
- revoked/expired grants stop access without waiting for a normal access-token expiry;
- disabled parent resources invalidate descendant operational access;
- system administrator access is explicitly audited;
- report downloads and cached dashboard results remain scoped after grant change.

### CSR Validation

Cover at least these attempt outcomes:

- charging confirmed successfully;
- charger offline/unavailable;
- OCPP command rejected;
- OCPP accepted but transaction/meter confirmation times out;
- valid authorization but charger communication failure;
- platform/service failure;
- manual driver cancel, excluded;
- driver card/payment failure, excluded according to the approved policy;
- normal stop, low-balance stop, idle transition, and unplug after a successful start, all remain CSR successes;
- duplicate/replayed events do not change counters twice;
- late event corrects a provisional record idempotently.

### Performance and Security Gates

- repository query plans use ownership indexes and do not fetch global rows for post-filtering;
- Elasticsearch queries contain authorized scope filters and tested bounded result sizes;
- admin event streams filter at publish/query time, not in browser memory;
- cache invalidation, projection lag, and authorization failures have Grafana/Splunk alerts;
- load test includes concurrent administrators across at least two enterprises while charging traffic is active;
- penetration-style tests attempt ID enumeration, header spoofing, stale-token reuse, replayed signed context, cross-scope report download, and async event leakage.

## Migration and Rollback Rules

1. Do not silently map an old generic role to global visibility. All non-system users require an explicit reviewed grant.
2. Backfill ownership snapshots using a deterministic mapping report. Flag ambiguities; do not assign them to a default tenant.
3. Reindex analytics and current-session documents after scope enrichment. Validate counts per location against the source before exposing dashboards.
4. Keep the legacy global dashboard only for system administrators during a short reconciliation period.
5. Enable scoped enforcement per pilot enterprise behind a feature flag, but never use a rollback that re-exposes another tenant's data to a scoped user.
6. If a scope projection is unavailable, deny sensitive reads/commands and show a recoverable service error. Do not fall back to global data.
7. Preserve audit history for grants and dangerous commands across migrations.

## Explicit Non-Goals for the First Release

- A flexible deny-policy language or arbitrary role editor. Start with a small approved role matrix and explicit grants.
- Site-level delegated administration. `Site` exists in older concepts but is not in the canonical charger-management hierarchy. Add it only after it has one authoritative owner and propagation model.
- Cross-enterprise reporting for tenant administrators.
- Exposing raw driver PII or payment data to location/network users.
- Claiming a verified CSR percentage before the attempt model and controlled tests are operational.

## Definition of Done

The work is complete only when all of the following are true:

1. A system administrator can create an enterprise, network, location, charger, and explicit scoped administrator grant.
2. A location operator sees only its location's chargers, sessions, receipts permitted by policy, connector state, dashboard, and CSR.
3. A network administrator sees only the aggregate of its locations and can never discover a sibling/foreign network through API, cache, export, event, or UI.
4. Every backend path applies scope server-side and has automated negative tests.
5. Ownership is immutable on session/attempt facts and available in analytics projections.
6. CSR is traceable to a documented attempt lifecycle with numerator, denominator, exclusions, and failure taxonomy.
7. Dashboard rollups are weighted and scoped; they do not expose unauthorized data or average child percentages.
8. Performance evidence demonstrates the scope design is projection/index/cache based, with no per-row remote authorization lookup.
9. Grant issuance, revocation, remote commands, and denied attempts are auditable.
10. A controlled pilot confirms isolation across at least two synthetic CPO tenants before a real micro-CPO is onboarded.

## Recommended Order of Work

Start with **Phase 0 and Phase 1 only**. The foundational decisions and authorization model must be stable before adding dashboard cards. Once resource-scoped session and charger enforcement is proven in Phase 2, the CSR and dashboard work can reuse the same ownership snapshots safely. This sequence avoids the common failure mode where an attractive dashboard is built on globally visible data and later requires a risky rewrite.

## Implementation and Production Validation (2026-07-17)

The first secure implementation slice is deployed to production. It establishes a server-enforced administrative scope boundary for chargers, sessions, analytics, and dashboard CSR rather than relying on hidden UI controls.

### Implemented Controls

| Area | Implemented behavior |
| --- | --- |
| Grant ownership | `user-service` owns `admin_scope_grants`, with explicit `ENTERPRISE`, `NETWORK`, and `LOCATION` grants and `READ` or `OPERATE` access. A system administrator can read or replace a user's grants through the administrative access API. |
| Gateway trust boundary | The API gateway removes client-supplied scope headers, resolves the authenticated user's grants, expands hierarchy roots to locations, caches the result briefly, and sends a signed, short-lived access context to downstream services. |
| Fail-closed default | A scoped administrator with no approved grant receives an empty scope. Reads return no tenant data and mutations are denied. The system never falls back to global visibility. |
| Charger administration | Charger, connector, EVSE, hierarchy, configuration, and operational commands apply read/operate scope checks in charger-management-service. |
| Session administration | Session search, receipt access, remote stop authorization, and the new CSR endpoint apply server-side location scope. |
| Analytics/dashboard | Billing Elasticsearch queries apply the allowed location filter. Dashboard cards and trends remain empty outside the caller's scope. CSR is returned from session-service as `successes / eligible starts`. |
| Portal experience | Scoped roles see only Dashboard, Enterprise, Network, Location, Charger Management, and Charging Sessions. Direct navigation to excluded screens shows `Not authorized`; it does not silently redirect or expose cached data. |
| Context evolution | Downstream parsers accept the canonical gateway scope payload while safely ignoring future claims. This prevents a valid signed context from breaking when the gateway adds a new hierarchy field. |

### CSR Definition in This Release

- Success: a charging start that reaches a completed or billed session.
- Failure: an invalid charging attempt, except a driver-card/payment failure.
- Excluded: local/manual cancellation, remote cancellation, unlock-command cancellation, and driver card/payment failure.
- Pending and active sessions do not affect the denominator until terminal.
- The endpoint is `GET /session/api/v1/sessions/admin/charging-success-rate` and uses the same server-side scope as session administration.

### Deliberate Interim Restriction

Subscription utilization is not yet backed by an immutable location/network ownership mapping. To avoid a cross-tenant data leak, scoped administrative roles are explicitly denied subscription administrative reads and the portal omits subscription-savings metrics and navigation for those roles. System administrators retain the existing global subscription workflow. This restriction stays in place until subscription allocations and utilization facts carry authoritative ownership dimensions and have scoped query tests.

### Production Releases

| Component | Relevant source changes | Production image |
| --- | --- | --- |
| API gateway | `63ec32d`, `ddf4e28`, `46a6ed6` | `amolsurjuse/api-gateway:rbac-scope-20260717-4` |
| User service | `f7db204`, `0164c59` | `amolsurjuse/user-service:rbac-scope-20260717-3` |
| Charger management | `8fce3ea`, `af1b69e` | `amolsurjuse/charger-management-service:rbac-scope-20260717-2` |
| Session service | `e8893b1`, `68c40f0`, `257d7fe` | `amolsurjuse/session-service:rbac-scope-20260717-3` |
| Billing service | `11fbf2e`, `6a48376`, `719524c` | `amolsurjuse/billing-service:rbac-scope-20260717-3` |
| Admin portal | `e01ad5e`, `5471506` | `amolsurjuse/admin-portal-ui:rbac-scope-20260717-2` |
| GitOps promotion | `55c0995`, `3b3cbb4` in `k8s-platform` | ArgoCD applications synchronized and healthy |

The shared production access-context secret is injected from a Kubernetes Secret into the gateway and all scope-verifying services. It is not recorded in source control or this document.

### Verification Evidence

- API gateway tests passed.
- User-service test suite passed, including Liquibase changes for grants and scoped-policy rules.
- Session-service test suite passed, including a regression test that signs the full canonical gateway payload with hierarchy claims and a future field.
- Admin portal production build passed.
- All affected ArgoCD applications reached `Synced` and `Healthy`; the session-service deployment reached `2/2` ready on `rbac-scope-20260717-3`.
- Production gateway health endpoint returned HTTP 200.
- A production read-only administrator browser test verified all of the following:
  - only the scoped-safe navigation items are shown;
  - global subscription savings is absent;
  - scoped dashboard analytics return zero records for an unassigned account;
  - CSR renders as `0.0%` with `0/0 eligible starts`, rather than failing;
  - charging sessions render an empty scoped result rather than a request error;
  - direct navigation to `/utilizations` returns the portal's `Not authorized` state;
  - no browser console errors were recorded.

### Remaining Work Before External Tenant Onboarding

1. Populate and review explicit grants for every non-system administrator, then test a positive location/network/enterprise scope with two synthetic tenants.
2. Add immutable ownership dimensions to subscription allocations, utilization facts, reports, notifications, audits, and exports before granting scoped access to those domains.
3. Add scope-aware event filtering, authorization-version invalidation, and scoped cache-key telemetry.
4. Create rollup/projection-backed tenant dashboards and validate weighted CSR totals under concurrent multi-tenant load.
5. Add end-to-end authorization-matrix and ID-enumeration regression scenarios to the TeamCity pipeline.
