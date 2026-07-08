# ElectraHub Performance and Latency Design Audit Plan

Date: 2026-07-07
Request: Strict audit of the application design with performance and latency in mind, covering every service and UI, followed by a detailed execution plan.
Status: Audit documented; no code changes made as part of this document.

## Scope

This audit covers the ElectraHub application estate currently present in the workspace:

- API gateway
- Auth service
- User service
- Station management service
- Charger management service
- OCPI service
- OCPP service
- Session service
- Payment service
- Pricing service
- Subscription service
- Billing service
- Notification service
- AI support service
- Web socket connector
- OCPI/OCPP simulator backend and UI
- Admin portal UI
- Driver portal iOS
- Driver portal Android
- Driver portal frontend
- Kubernetes and platform manifests
- TeamCity/JMeter regression flow where relevant

## Highest-Risk Findings

### 1. API Gateway latency boundaries are not strict enough

The gateway is the first shared choke point. It proxies service calls and has special handling for streaming paths. The design needs explicit per-route latency budgets, connection pooling, circuit breakers, request limits, and backpressure behavior.

Risk:

- Slow downstream services can consume gateway worker capacity.
- REST, SSE, and WebSocket-style paths may require different timeout behavior.
- Missing route-level budgets can hide latency regressions until load testing.

Plan:

- Add pooled HTTP client configuration.
- Define connect, read, write, and total request timeouts per route class.
- Add circuit breakers, bulkheads, and retry only for idempotent calls.
- Add request/response size caps.
- Separate SSE and long-lived stream handling from ordinary REST proxy behavior.
- Add gateway metrics for downstream latency, error rate, timeout count, open circuit count, and active connections.

### 2. Session service is the core hot path

Session service coordinates active charging, stop charging, idle state, unplug handling, receipt handoff, active-session APIs, SSE streaming, low-balance behavior, idle fees, and Redis state.

Risk:

- Start/stop flows touch pricing, payment, OCPP, Redis, database, SSE, and billing/receipt logic.
- One slow dependency can cascade into user-visible latency.
- Idle-fee sessions require a very careful state machine so the app does not jump to receipt before unplug.

Plan:

- Break charging start/stop into explicit measured stages.
- Cache tariff, idle-fee, fee-cap, tax, and subscription eligibility for the life of a session.
- Keep receipt generation asynchronous and never let it override an active idle state before unplug.
- Use Redis atomic claim or lock patterns for scheduled idle processing.
- Add bounded batch sizes to reconciliation and idle ticker jobs.
- Make SSE fanout horizontally safe using shared event propagation or a dedicated event broker.
- Add p95/p99 metrics for active-session reads, stop request, idle transition, unplug transition, receipt readiness, Redis latency, and downstream calls.

### 3. Analytics and dashboard paths can become expensive

Billing analytics and admin dashboard/list screens show patterns that can become expensive with production data, especially in-memory pagination and offset-style searches.

Risk:

- Dashboard filters may scan too much historical data.
- Admin list pages can fetch too much data and paginate in the browser.
- Offset pagination becomes slower as data grows.
- Percentage comparisons can be misleading if filter boundaries differ between current and previous periods.

Plan:

- Move pagination into the database or Elasticsearch.
- Use cursor/search-after pagination for deep analytics queries.
- Add materialized daily/hourly summary tables for dashboard cards.
- Define one shared filter-period calculation library for current period and previous period comparisons.
- Add tests that compare dashboard API output against direct database queries.
- Add query plans for top dashboard filters before adding indexes.

### 4. OCPP command handling needs stronger bounds

The OCPP service manages WebSocket connections, remote commands, pending futures, heartbeat monitoring, and message logs.

Risk:

- Pending command maps can grow if chargers do not respond.
- Message logs can become write-heavy and query-heavy.
- Remote command latency directly affects stop/unplug behavior.

Plan:

- Add global and per-charger pending command limits.
- Ensure every pending command has timeout cleanup.
- Separate executor pools for socket IO, command dispatch, and persistence.
- Add queue depth metrics.
- Partition or archive OCPP message logs.
- Add p95/p99 metrics for Authorize, StartTransaction, StopTransaction, StatusNotification, MeterValues, UnlockConnector, and RemoteStopTransaction.

### 5. Redis is central to charging behavior

Redis is used for active sessions, idle fee state, simulator access, refresh/session state, and coordination.

Risk:

- Redis latency affects active charging UX.
- Single-node Redis or weak resource settings can cause system-wide symptoms.
- Key scans or large unbounded sets can become expensive.

Plan:

- Review Redis HA, persistence, memory limit, eviction policy, and backup strategy.
- Replace any broad key scans with indexed sets or cursor-safe operations.
- Add atomic scripts where multiple Redis operations represent one state transition.
- Add Redis command latency metrics and key cardinality dashboards.
- Define TTL policy for simulator access, stale sessions, receipts, and inactive stream data.

### 6. UI state and network behavior need tightening

Mobile apps, admin portal, driver portal, and simulator UI all affect perceived latency.

Risk:

- Mobile active charging may combine SSE and fallback polling in ways that duplicate or reorder state transitions.
- Large map/list screens can render too much at once.
- Admin screens can fetch too much data and re-fetch on filter changes.
- Simulator UI can render too much connector inventory when a single connector HMI is needed.

Plan:

- Make active charging state machines explicit on iOS and Android.
- Ensure SSE and polling are mutually coordinated.
- Add request cancellation and stale-response protection in UI clients.
- Use server-side pagination for admin and simulator lists.
- Use mobile map clustering and viewport-based charger loading.
- Keep simulator connector HMI routes direct and lightweight.

## Service-by-Service Plan

### API Gateway

- Add pooled HTTP client with configured max connections and idle eviction.
- Add per-route timeout budgets.
- Add circuit breakers and bulkheads by downstream service.
- Add request/response size limits.
- Keep SSE and long-lived paths isolated from normal REST calls.
- Add structured gateway logs with request id, user id, route id, downstream service, status, duration, and timeout reason.

### Auth Service

- Validate Redis access patterns for refresh/device cookies.
- Add rate limits for login, refresh, and OTP-style flows.
- Ensure token lookup fields are indexed.
- Cache stable auth metadata where safe.
- Add metrics for login, refresh, token verification, Redis latency, and DB latency.

### User Service

- Require pagination for admin user list/search APIs.
- Add indexes for email, phone, status, role, organization, and normalized search fields.
- Avoid heavy count queries on every UI filter change.
- Cache low-change profile metadata when used by multiple services.

### Station Management Service

- Use projection DTOs for charger/location/connector list APIs.
- Avoid N+1 loading across stations, EVSEs, connectors, tariffs, and status history.
- Add or validate indexes for location, network, station, EVSE, connector status, and organization.
- Cache mostly-static station/location metadata.

### Charger Management Service

- Separate static charger metadata from live connector status.
- Cache charger identity, connector references, and network/location metadata.
- Keep live status reads indexed and bounded.
- Add metrics for charger lookup, connector status lookup, and update ingestion.

### OCPI Service

- Bound partner sync batches.
- Add partner-specific timeout/retry policies.
- Use cursor-based pagination for locations, sessions, tokens, and CDRs.
- Ensure sync queue has indexes on status, partner, next attempt, and created time.
- Add idempotency for incoming updates.

### OCPP Service

- Bound pending command state.
- Add timeout cleanup and metrics for every command type.
- Separate socket IO from persistence work.
- Reduce synchronous writes on high-frequency MeterValues where possible.
- Partition or archive OCPP logs.
- Add connection-level metrics and charger-level health state.

### Session Service

- Make charging lifecycle state transitions explicit and idempotent.
- Separate charging stop from receipt generation when idle fee requires unplug.
- Keep pricing/subscription/payment snapshots on the session to avoid repeated lookups.
- Add low-balance auto-stop checks with configurable thresholds.
- Add idle-fee and session-fee caps from price plan config.
- Bound scheduled jobs and use Redis atomic claiming.
- Add SSE replay or last-known-state support for mobile reconnects.

### Payment Service

- Keep wallet debit, holds, captures, refunds, and top-ups idempotent.
- Avoid external payment-provider calls inside long database transactions.
- Add auto top-up as a bounded, observable path.
- Add indexes for wallet, user, transaction status, session authorization, and idempotency key.
- Add metrics for provider latency, wallet lock wait, authorization expiry, top-up success, and top-up failure.

### Pricing Service

- Cache active tariffs and price plans by location, connector type, tenant, network, and validity window.
- Precompute fee cap and idle-fee rules for charging sessions.
- Add invalidation when price plans change.
- Add tests for tax, subscription interaction, idle fee, max idle fee, and max session fee.

### Subscription Service

- Cache active subscription eligibility and remaining quota for charging-session use.
- Add indexes for user, plan, status, validity window, and quota unit.
- Avoid recalculating subscription coverage repeatedly during meter updates.
- Document any memory increases with before/after heap, cache, and query evidence.

### Billing Service

- Push pagination to DB or Elasticsearch.
- Use materialized views or summary tables for dashboard cards.
- Use search-after or cursor pagination for deep analytics.
- Split receipt lines into energy, idle fee, taxes, discounts, and total.
- Add reconciliation tests between session cost and billing receipt.

### Notification Service

- Queue notification sends asynchronously.
- Batch device-token fanout.
- Add provider timeouts and retry policies.
- Add dead-letter handling for repeated failures.

### AI Support Service

- Isolate LLM latency from core charging and payment APIs.
- Add timeout and token budgets per request.
- Stream responses with cancellation support.
- Add circuit breaker behavior for upstream LLM failures.

### Web Socket Connector

- Bound connection maps and outbound queues.
- Add heartbeat and reconnect metrics.
- Drop or backpressure noisy clients explicitly.
- Add per-connection memory and message-rate monitoring.

### Simulator Backend and UI

- Keep charger list API paginated and metadata-rich.
- Do not load all chargers for single connector HMI routes.
- Keep direct HMI route for connector operations.
- Avoid global frequent re-renders.
- Cap rendered event history.
- Show charger, connector, location, network, and status clearly on mobile.

### Admin Portal UI

- Replace client-side pagination with server-side pagination.
- Add abortable fetches for filter changes.
- Cache lookup/reference data.
- Lazy-load route bundles.
- Validate dashboard percentages against database-backed calculations.
- Add empty, loading, partial-error, and stale-data states.

### Driver Portal iOS

- Implement explicit active-charging state machine.
- Coordinate SSE and polling to avoid duplicate transitions.
- Keep idle screen visible until unplug when idle fee applies.
- Avoid navigating to receipt before unplug completion.
- Add map clustering and viewport-based charger queries.
- Split large stateful views where render cost is high.

### Driver Portal Android

- Match iOS state machine and receipt/idle behavior.
- Use lifecycle-aware SSE cancellation.
- Add paging for charger and history lists.
- Configure OkHttp timeouts, retry behavior, and connection pooling.
- Add stale-response protection when users switch screens.

### Driver Portal Frontend and Org Page

- Keep static assets cacheable.
- Avoid polling when tabs are hidden.
- Split large bundles by route.
- Add request timeout and retry standards.

### Kubernetes and Platform

- Add HPA or KEDA for gateway, session, payment, pricing, OCPP, OCPI, billing, admin UI, and simulator.
- Add pod disruption budgets for critical services.
- Verify readiness, liveness, and startup probes are meaningful.
- Review Redis, Postgres, RabbitMQ, TeamCity agent, Splunk, Prometheus, and Grafana resource sizing.
- Separate ingress timeout settings for REST, SSE, and WebSocket traffic.
- Add platform dashboards for CPU, memory, GC, DB pool, Redis latency, queue depth, ingress latency, and error rate.

## Validation Plan

### Load Tests

Run these cycles through the TeamCity regression pipeline and JMeter scripts:

- 50 concurrent users
- 100 concurrent users
- 200 concurrent users
- 100-user burst load

Required charging scenarios:

- Start charging
- Stop charging without idle fee
- Stop charging with idle fee
- Idle fee accrual
- Unplug after idle
- Receipt generation
- Low balance auto-stop
- Auto top-up with valid card
- Auto top-up failure
- Simulator HMI RFID authorization
- Simulator HMI credit-card authorization
- Plug and Charge flow

### Performance Gates

Initial target gates:

- Start charging p95 under 2 seconds
- Stop charging API p95 under 2 seconds
- Idle transition visible in app under 1 second after event
- Receipt available under 5 seconds after unplug
- Active sessions API p95 under 500 ms
- Admin dashboard p95 under 1.5 seconds
- Simulator charger list p95 under 700 ms with 1,000 chargers
- Error rate under 1 percent during 200-user test
- No unbounded growth in pending OCPP commands, SSE emitters, Redis active session sets, or UI event logs

### Database Validation

For top APIs, capture and review query plans:

- Active sessions
- Charging session by user
- Charging history
- Receipt lookup
- Dashboard cards
- Dashboard trend filters
- Billing analytics
- Charger list
- Connector status
- OCPI sync queues
- OCPP message logs

Use `EXPLAIN ANALYZE` before adding indexes.

### Observability Validation

Each critical service should publish:

- Request count
- Error count
- p50/p95/p99 latency
- DB query latency
- Redis latency
- Downstream dependency latency
- Queue depth
- Thread pool or executor saturation
- JVM heap and GC pauses where applicable
- Container CPU and memory

## Execution Sequence

### Phase 0: Baseline

- Run 50-user load test.
- Capture service metrics, DB slow queries, Redis latency, gateway latency, and mobile/API behavior.
- Record current p50/p95/p99 values.

### Phase 1: Guardrails

- Add gateway and service timeouts.
- Add connection pools, circuit breakers, and bulkheads.
- Add missing autoscaling and resource limits.
- Add missing dashboards and alerts.

### Phase 2: Charging Hot Path

- Optimize session start, stop, idle, unplug, and receipt behavior.
- Fix low-balance, auto top-up, idle-fee cap, and session-fee cap behavior.
- Validate with focused JMeter tests.

### Phase 3: Data and Analytics

- Fix dashboard correctness and latency.
- Replace in-memory pagination.
- Add materialized summaries where needed.
- Add database indexes based on query plans.

### Phase 4: UI Performance

- Fix iOS and Android active charging state transitions.
- Optimize admin dashboard and list screens.
- Optimize simulator single-connector HMI flow.
- Add mobile network throttling validation.

### Phase 5: Regression Gates

- Add new JMeter cases to the regression pipeline.
- Run 50, 100, 200, and burst tests.
- Block release if target gates fail.

## Open Decisions

- Whether to use Redis pub/sub, RabbitMQ, Kafka, or another event stream for multi-node SSE delivery.
- Whether dashboard summaries should live in billing service, session service, or a dedicated analytics store.
- Whether charging cost should be recalculated continuously or snapshotted with periodic reconciliation.
- Whether TeamCity should maintain separate simulator backend/UI pipelines or a single combined OCPP simulator pipeline.

## Next Step

Convert this plan into execution tickets or workflow request folders by phase. The first implementation phase should be baseline measurement and guardrails before making service-level optimizations.
