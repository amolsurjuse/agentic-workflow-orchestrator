# Low-Balance Stop Remained Charging

## Request

Investigate `EH-US-CHG-0301 / Connector 1`, where charging appeared to have stopped because of low wallet balance but the connector continued to report `Charging`.

Production identifiers:

- Charger: `EH-US-CHG-0301`
- Connector reference: `CON-US-0301`
- OCPP connector number: `1`
- Session: `48a54ddc-1526-42ed-a1d4-dd52eccde62a`
- OCPP transaction: `161419700`

## Expected Flow

1. A meter update recalculates the projected session charge.
2. `session-service` asks `payment-service` to evaluate wallet balance and auto top-up.
3. If the balance remains below the configured threshold, `session-service` persists `FINISHING` with stop reason `LOW_BALANCE`.
4. After that database transaction commits, `session-service` dispatches an OCPP remote stop.
5. The charger emits `StopTransaction` and a suspended status.
6. When idle fees are enabled, the session remains `SUSPENDED` and requires unplug; it must no longer report active charging or deliver power.
7. Physical unplug completes the session and starts receipt settlement.

## Root Cause

Production PostgreSQL had an older Hibernate-generated `charging_sessions_stop_reason_check` constraint that did not include `LOW_BALANCE`.

The low-balance update failed at `saveAndFlush` with:

```text
new row for relation "charging_sessions" violates check constraint
"charging_sessions_stop_reason_check"
```

Because the transaction rolled back, its after-commit remote-stop callback never ran. The simulator therefore retained the transaction and continued reporting `Charging`.

Production also disables Liquibase and uses Hibernate `ddl-auto=update`, so adding only a normal migration would not repair deployed environments. A runtime compatibility check is required until production schema management is standardized.

## Immediate Recovery

The production constraint was transactionally rebuilt with all current `StopReason` enum values, including `LOW_BALANCE`. The next meter update then completed the normal flow:

- `LOW_BALANCE_STOP_REQUESTED`
- OCPP `RemoteStopTransaction` accepted
- OCPP `StopTransaction` received
- Session transitioned to `SUSPENDED`
- Connector transitioned from `Charging` to `SuspendedEV`

The remaining active-session entry is intentional because this price plan has idle fees enabled and requires physical unplug before receipt generation.

## Permanent Changes

### session-service

- Add Liquibase change set `017-update-stop-reason-check.yaml`.
- Add an idempotent PostgreSQL startup compatibility guard for deployments where Liquibase is disabled.
- Serialize the compatibility update across replicas with a PostgreSQL transaction advisory lock.
- Rebuild the constraint only when one or more current enum values are missing.
- Preserve `LOW_BALANCE` when the charger reports the generic OCPP stop reason `Remote`.

### ocpp-service

- Translate protocol status `SuspendedEV` to station domain status `SUSPENDED_EV`.
- Translate `SuspendedEVSE` to `SUSPENDED_EVSE`.
- Continue sending the original OCPP status to `session-service`.

### Regression

- Tighten the low-balance JMeter flow so `FINISHING` or a stop-request marker alone cannot pass.
- Require the session to reach `SUSPENDED`, `COMPLETED`, or `STOPPED`, then validate unplug and receipt completion.

## Validation

- [x] Production database constraint repaired.
- [x] Reported charger no longer reports `Charging`.
- [x] Reported session is `SUSPENDED` and awaiting unplug as required by the idle-fee plan.
- [x] session-service focused tests passed.
- [x] session-service full suite passed: 61 tests.
- [x] OCPP focused tests passed.
- [x] OCPP full suite passed: 17 tests.
- [ ] Changes committed and pushed to `develop`.
- [ ] TeamCity builds completed.
- [ ] Production images deployed and Argo applications healthy.
- [ ] Post-deployment low-balance regression completed.

## Follow-Up Design Debt

Production should move from Hibernate schema mutation to Liquibase with `ddl-auto=validate`. The compatibility guard is deliberately idempotent and safe for the current deployment model, but one migration owner is preferable to maintaining two schema paths.
