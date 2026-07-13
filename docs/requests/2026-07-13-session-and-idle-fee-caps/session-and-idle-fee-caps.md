# Charging Session and Idle Fee Caps

## Requirement

Every pricing plan must define a maximum charge for one charging session. A plan that enables idle fees must also define a maximum idle-fee charge. The cap amount uses the pricing plan currency, so `100.00` means USD 100 for a USD plan and EUR 100 for a EUR plan.

## Business Rules

| Rule | Default | Override level |
|---|---:|---|
| Maximum session charge | 100.00 | Pricing plan |
| Maximum idle fee | 50.00 | PARKING tariff component |

The idle-fee cap is applied to the PARKING component first. The maximum session charge is then applied to the sum of ENERGY, TIME, PARKING, and FLAT charges. Subscription discounts are calculated from that capped gross amount. Settlement, active-session responses, SSE events, Elasticsearch projections, and receipts use the same capped values.

The maximum session charge is the final pricing ceiling for the session subtotal. For example, an ENERGY/TIME subtotal of 90.00 and a capped idle fee of 20.00 produce a 110.00 subtotal, which becomes 100.00 when the plan session cap is 100.00.

## Runtime Flow

1. Admin creates or updates a pricing plan with `maxTotalCost`.
2. A PARKING component stores its idle-fee limit in `maxPrice`.
3. Pricing Service backfills legacy plans to 100.00 and legacy PARKING components to 50.00.
4. At session start, Session Service snapshots `maxIdleFee` and `maxTotalCost` from Pricing Service onto the charging session.
5. Pricing Service calculates and caps PARKING cost, then caps the complete session subtotal.
6. Session Service persists the capped gross and post-subscription net cost.
7. Redis/SSE and Elasticsearch projections publish the persisted capped amount without adding idle fees a second time.
8. Low-balance checks, payment settlement, history, and receipt generation consume the same capped session state.

## API Contract

Pricing plan create/update:

```json
{
  "currency": "USD",
  "maxTotalCost": 100.00,
  "components": [
    {
      "dimension": "PARKING",
      "price": 2.00,
      "currency": "USD",
      "maxPrice": 50.00
    }
  ]
}
```

Idle-fee policy response includes both cap snapshots:

```json
{
  "enabled": true,
  "pricePerMinute": 2.00,
  "gracePeriodSeconds": 300,
  "maxIdleFee": 50.00,
  "maxTotalCost": 100.00,
  "currency": "USD"
}
```

## Persistence

- Pricing Service: `pricing_plans.max_total_cost`
- Pricing Service: `pricing_components.max_price` for `dimension = 'PARKING'`
- Session Service snapshot: `charging_sessions.session_max_amount`
- Session Service snapshot: `charging_sessions.idle_fee_max_amount`

## Compatibility

- Existing pricing plans are backfilled during Liquibase migration.
- Missing legacy values are also protected by runtime defaults.
- Existing API clients remain compatible because the idle-policy response only adds `maxTotalCost`.
- Sessions that started before cap snapshots existed retain their persisted behavior; new calculations snapshot the applicable plan cap.

## Validation

- Pricing Service unit tests verify idle-first/session-second cap ordering, legacy defaults, and realtime cap enforcement.
- Session Service unit tests verify whole-minute idle billing, idle-fee clamping, session-total clamping, and legacy sessions without snapshots.
- Admin Portal TypeScript and Vite production build verify the pricing form and response model.
