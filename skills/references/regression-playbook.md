# Regression Playbook

Use this when running or interpreting ElectraHub regression, JMeter, TeamCity, SSE, OCPP/OCPI, CDR, or dashboard validation.

## Environment Selection

- Use dev unless the user explicitly says prod or the failure only exists in prod.
- Use prod for live public-domain or customer-impact validation only when requested.

## Charging Flow Checks

Minimum end-to-end flow:

1. Login as a valid CUSTOMER driver.
2. Validate profile, terms, and wallet/payment state.
3. Discover chargers through charger GraphQL.
4. Select an available connector.
5. Start session with:
   - `chargerId`: OCPP charger identity, for example `EH-SFO-CHG-001`
   - `locationId`: OCPI location id, for example `US*EHB*LOC*SFO001`
   - `connectorId`: backend connector string, for example `CON-SFO-001`
   - `connectorNumber`: OCPP numeric connector id, for example `1`
6. Confirm active session leaves `PREPARING`.
7. Confirm SSE emits snapshot/session update events.
8. Confirm meter-derived fields move:
   - `energyDeliveredKwh`
   - `currentPowerKw`
   - `estimatedCost`
   - status
9. Stop session.
10. Confirm terminal state and disappearance from `/sessions/active`.
11. Confirm CDR/receipt generation.
12. Confirm admin dashboard analytics reflect the session after ingestion.

## Concurrency Checks

- Two users starting the same connector concurrently must produce one active session.
- Loser should receive clean `409 Conflict`.
- DB constraints or transactional locking must enforce the rule.

## Load Test Checks

For JMeter:

- Use ramped concurrency, not instant full load, unless testing spike behavior.
- Record users, ramp seconds, hold seconds, SSE duration, target environment, and connector selection strategy.
- Validate the test harness does not misuse charger sequence as connector number.
- Separate SSL/DNS/test-container issues from product errors.

## Common Failure Classifications

| Symptom | Likely owner |
| --- | --- |
| SSL handshake failure in JMeter only | `k8s-platform` JMeter container/JDK/TLS config |
| `Read timed out` during many parallel sessions | capacity, gateway/session/ocpp latency |
| session remains `PREPARING` | `session-service`, `ocpp-service`, simulator, remote start path |
| no meter/cost movement | `ocpp-service`, `session-service`, pricing/tariff integration |
| session remains active after stop | `session-service` stop reconciliation |
| admin dashboard missing completed sessions | `billing-service`, eventing, Elasticsearch |
| all chargers unavailable | `ocpp-service` heartbeat/status propagation, station/charger management |

## Required Evidence

Capture:

- environment
- base URL
- request path
- status and body summary
- session id
- charger id
- connector id and connector number
- trace id when available
- TeamCity/JMeter build URL when applicable

Never include full JWTs, passwords, refresh tokens, payment card data, or secret values.
