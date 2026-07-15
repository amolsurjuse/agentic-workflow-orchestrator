# False Idle And Battery Notifications

## Original Request

The iOS notification inbox showed `Battery full`, `Idle fees may start soon`, and
`Idle period started` immediately after a charging session started, even though
the connector remained actively charging.

## Scope

- OCPP 1.6 and OCPP 2.0.1 meter-value ingestion
- Charging-session state transitions and notification publication
- Simulator periodic telemetry
- iOS notification inbox validation
- Production rollout and event-stream verification

The iOS client is not changed. It rendered notification records produced by the
backend as designed.

## Production Evidence

- Driver account: `eda84789-2a1c-42de-844f-72efd53cea16`
- Session: `c59ee7f5-882d-43ed-99ac-01454f3f95f8`
- Charger: `EH-US-CHG-0201`
- `CHARGING_SESSION_STARTED` was created at approximately `2026-07-15T21:18:42Z`.
- Idle-started, idle-warning, and battery-full events followed at approximately
  `2026-07-15T21:18:50Z` while the charger still reported `Charging`.

## Root Cause

The simulator's periodic meter message contained energy but omitted power and
state of charge. OCPP-service converted the missing power value to numeric zero.
Session-service interpreted low power as both an idle transition and a full
battery. This made a partial telemetry message override the explicit OCPP
`StatusNotification=Charging` state.

## Design Decisions

1. Missing OCPP measurands remain absent; ingestion must not manufacture zeroes.
2. OCPP status notifications own charging versus suspended/idle state.
3. Meter values update energy, power, state of charge, and real-time cost. A
   low or absent power sample does not start an idle period.
4. Battery-full is emitted only when the charger explicitly reports SoC at or
   above 100 percent.
5. A Redis `SET NX` milestone permits battery-full publication once per session
   across service replicas. Existing notification deduplication remains a
   downstream safety net.
6. Simulator periodic telemetry reports configured power and calculated SoC so
   its behavior resembles a real charger.

## Repositories Changed

- `session-service`: authoritative state transition, explicit SoC rule, and
  distributed battery-full milestone.
- `ocpp-service`: nullable energy/power/SoC extraction for OCPP 1.6 and 2.0.1.
- `ocpi-simulator`: periodic power and SoC meter samples.
- `agentic-workflow-orchestrator`: this incident and release record.

## Validation

- Session-service focused state and Redis tests: 45 passed.
- Session-service full test suite: 71 passed before the final focused refactor;
  the affected focused suite was rerun afterward.
- OCPP-service full test suite: 20 passed.
- Simulator `internal/app` and `internal/fleet` tests passed.
- Production verification must confirm an actively charging connector produces
  no idle or battery-full notification until an explicit suspended/idle status
  or SoC 100 reading is received.

## Protocol And Product Impact

- OCPP: meter values preserve optional-measurand semantics; status remains the
  connector-state authority.
- Sessions: prevents false `ACTIVE -> SUSPENDED` transitions.
- Pricing/payment/CDR: no formula changes; preventing false idle transitions
  also prevents idle fees from being started by missing telemetry.
- OCPI, RBAC, and tenant boundaries: no contract or authorization changes.
- Clients: fixes iOS and Android notification data at the shared backend source.

## Status

Implementation and automated verification are complete. Commit, CI rollout,
and production event verification follow this record.
