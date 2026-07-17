# Real-Time Cost Tariff Snapshot Fix

## Request

Correct live charging cost so it matches the tariff shown on the connector details screen.

## Observed Evidence

- Connector details showed an energy rate of `$0.31/kWh`, a time rate of `$0.05/min`, and no session fee.
- At `1.1 kWh` and `1 minute 35 seconds`, the live screen showed `$0.18`.
- The expected pre-tax, pre-discount tariff amount is `$0.4202`:
  - energy: `1.1 x 0.31 = 0.3410`
  - time: `(95 / 60) x 0.05 = 0.0792`
  - total: `0.4202`

## Root Cause

The session service treated an OCPI `tariffId` as a pricing-plan UUID. The pricing calculation endpoint did not use that field in its public request contract and instead resolved a generic applicable plan. This allowed a different default plan to calculate the session while the driver saw the OCPI connector tariff.

## Design

1. On session start, resolve the connector tariff from the OCPI connector index.
2. Persist immutable energy, time, and flat-fee components with the session.
3. Calculate live and final gross cost from that snapshot:
   - energy delivered x energy rate
   - elapsed minutes x time rate
   - one-time flat fee
   - capped idle fee, when applicable
   - capped session total
4. Apply the existing server-side subscription preview to the calculated gross cost.
5. Keep the existing pricing-service calculation only as a fallback for connectors with no published OCPI tariff.
6. Do not infer a pricing-plan association from an OCPI tariff UUID.
7. For active sessions created before the database change, hydrate the snapshot once on the next active-session read, recalculate, and refresh Redis, Elasticsearch, and SSE projections.

## Non-Goals

- The mobile client does not calculate pricing business logic.
- Tax and final payment settlement behavior remains unchanged; the receipt retains the existing settlement path.
- Historical completed sessions are not rewritten.

## Validation Plan

- Unit test the screenshot example and flat/idle-fee cap calculation.
- Unit test that explicitly free tariffs are snapshotable.
- Run the session-service Maven test suite.
- Deploy the new session-service image through the production GitOps path.
- Confirm an active connector session uses the same energy/time rates as its connector tariff and that the active API, Redis projection, and SSE response agree.

## Verification Completed

- Session-service Maven test suite passed in the Maven 3.9.9 / Temurin 21 container.
- Production deployed through the normal GitOps path with CI image tag `93`.
- Argo CD reported the session-service application as `Synced` and `Healthy` with two available replicas.
- Both production pods logged successful verification of the tariff snapshot database columns.
- A live connector session was reprojected with its connector tariff rates:
  - energy rate: `$0.31/kWh`
  - time rate: `$0.05/min`
  - flat fee: `$0.00`
  - no idle time accrued
- Its gross cost matched the server formula using the latest meter value and whole elapsed seconds, and the displayed amount matched the same server-side subscription discount in both Redis and Elasticsearch projections.
