# Realtime Pricing Consistency

## Request

Make connector pricing, live charging cost, idle-fee messaging, final settlement, and receipts use one authoritative tariff. Connector `CON-US-0196` displayed `$0.41/kWh + $0.05/min`, no idle fee, and no session fee, while its active session included an unrelated `$1` flat fee and advertised `$3/min` idle pricing.

## Production Evidence

- OCPI connector: `CON-US-0196`
- Charger: `EH-US-CHG-0196`
- Location: `US*EHB*LOC*USA040`
- Connector tariff: `9f000000-0000-0000-0000-000000000196`
- Correct components: energy `$0.41/kWh`, time `$0.05/min`, parking `$0`, flat `$0`
- Incorrect session snapshot: idle enabled at `$3/min`
- Incorrect pricing fallback: connector-scoped tariff `051`, including parking `$3/min` and flat `$1`

## Root Cause

1. Session-service sent the connector reference, such as `CON-US-0196`, as the pricing `connectorType`.
2. Pricing-service could not match that value to the tariff's `CHADEMO` connector type.
3. The global-plan query treated any plan without a location as global, even when it was scoped to a different connector type.
4. Explicit zero parking prices were discarded as if no connector policy existed, allowing the unrelated fallback idle policy to replace `$0` with `$3/min`.
5. The active iOS screen rendered the backend session response. It did not introduce the extra fee.

## Design

### Pricing Service

- Session and idle-policy requests may carry an optional exact `pricingPlanId`.
- An exact plan ID takes precedence over location/type fallback selection.
- Connector type values are normalized before fallback matching.
- A global plan must have both no location and no connector type.
- A zero-priced parking component is an explicit disabled idle policy.
- Zero energy is valid for pricing at the beginning of a session.
- Existing gRPC callers remain compatible and continue using fallback selection.

### Session Service

- Resolve the connector's OCPI tariff when charging starts.
- Persist tariff ID, pricing plan ID, and normalized connector type on the session.
- Preserve explicit zero idle pricing from the connector tariff.
- Use the persisted plan for realtime meter updates and final cost calculation.
- Backfill tariff identity for active sessions created before this change.
- Keep pricing and idle-fee business logic in backend services; mobile clients render the authoritative response.

## Database Change

Session-service change set `018-add-session-pricing-snapshot` adds nullable columns:

- `pricing_plan_id UUID`
- `tariff_id VARCHAR(128)`
- `pricing_connector_type VARCHAR(50)`

The columns are nullable to allow a rolling deployment and legacy-session backfill.

## Validation

- Pricing-service commit: `c6ff2e3` (`fix: pin charging cost to connector tariff`).
- Pricing-service energy-step commit: `a8f5db2` (`fix: apply OCPI energy steps in watt-hours`).
- Session-service commit: `09bc5a3` (`fix: keep session pricing aligned with connector tariff`).
- Pricing-service tests: `6/6` passed.
- Session-service tests: `64/64` passed.
- Explicit-zero OCPI tariff regression passed.
- Pinned-plan selection regression passed.
- Connector `0196` arithmetic regression passed:
  - energy: `0.700 kWh * $0.41 = $0.2870`
  - time: `62 seconds * $0.05/min = $0.0517`
  - parking: `$0.0000`
  - flat fee: `$0.00`
  - gross total: `$0.3387`
- OCPI 2.2.1 defines `ENERGY step_size` in Wh; `step_size=1` bills with 1 Wh precision:
  - https://github.com/ocpi/ocpi/blob/release-2.2.1-bugfixes/mod_tariffs.asciidoc
- `git diff --check` passed in both backend repositories.
- TeamCity pricing builds `17` and `18` passed.
- TeamCity session build `84` passed.
- Production images deployed: `pricing-service:18`, `session-service:84`.
- Production exact-plan API returned energy `$0.2870`, time `$0.0517`, parking `$0`, flat `$0`, total `$0.3387`.
- Production idle-policy API returned `enabled=false` and `pricePerMinute=0`.
- The legacy active session was backfilled to tariff `...0196`; its Redis projection reports idle disabled and zero idle amount.

## Acceptance Criteria

- [x] Connector detail and active session resolve the same tariff.
- [x] No unrelated `$1` flat fee is added.
- [x] Explicit `$0` idle pricing disables idle fees.
- [x] Realtime and final calculations use the same pinned pricing plan.
- [x] Existing active sessions can acquire the correct tariff snapshot.
- [x] Backend tests cover the reported tariff.
- [x] Deploy pricing-service and session-service builds.
- [x] Validate the production active-session projection and pricing APIs.
