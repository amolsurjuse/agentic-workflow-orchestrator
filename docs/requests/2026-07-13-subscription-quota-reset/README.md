# Subscription Quota Reset To 5,000 kWh

## Request

Reset the new-driver subscription entitlement for every user, increase the energy quota from 500 kWh to 5,000 kWh, and make each affected allocation report 100% quota remaining.

## Production Baseline

Plan code: `NEW_USER_20_OFF_500KWH_1Y`

The plan code is retained as a stable system identifier because session records, integrations, and clients already reference it. User-facing plan text and effective quota are updated to 5,000 kWh.

Observed before the reset:

| Measure | Count |
| --- | ---: |
| Allocations | 963 |
| Active allocations | 963 |
| Exhausted allocations | 5 |
| Partially used allocations | 749 |
| Unused allocations | 209 |
| Plan quota | 500 kWh |

## Implementation

Repository: `subscription-service`

Liquibase change set: `0004-reset-new-user-promo-quota-to-5000-kwh`

The change set executes atomically:

1. Resolve the target plan by its stable code.
2. Fail the deployment if the plan does not exist.
3. Write one `ALLOCATION_QUOTA_RESET` audit record for every allocation.
4. Preserve each allocation's previous quota and consumed values as structured JSON in the audit detail.
5. Set allocation quota limits to 5,000 kWh.
6. Set allocation consumed counters to zero.
7. Increase optimistic-lock versions and update timestamps.
8. Set the plan's default quota to 5,000 kWh for future allocations.
9. Update the user-facing plan description from 500 kWh to 5,000 kWh.

Historical utilization rows are retained. They remain the immutable record of charging benefits already applied, while the allocation counter begins a new entitlement period.

## Expected API State

For every active allocation returned by:

`GET /subscription/api/v1/driver/subscriptions/me?activeOnly=true&limit=20&offset=0`

the target plan must report:

```json
{
  "quotaUnit": "KWH",
  "quotaLimitValue": 5000.0000,
  "consumedValue": 0.0000,
  "remainingValue": 5000.0000,
  "status": "ACTIVE"
}
```

This corresponds to 100% remaining quota.

## Validation

- Run the service test suite with JDK 21.
- Rehearse the complete SQL change inside `BEGIN` / `ROLLBACK` against production.
- Export the target plan and allocation rows before deployment.
- Deploy the subscription service and wait for Liquibase to complete.
- Verify the plan quota, allocation count, reset counters, and audit count directly in PostgreSQL.
- Verify the driver subscription API for a known affected user.
- Confirm a new charging session receives the subscription discount and no longer reports `subscriptionQuotaExhausted: true` before consuming the new quota.

## Rollback

The Liquibase rollback reads each allocation's prior values from its deterministic audit record, restores those values, removes reset audit entries, and returns the plan default and description to 500 kWh. The pre-deployment export provides an additional recovery source.
