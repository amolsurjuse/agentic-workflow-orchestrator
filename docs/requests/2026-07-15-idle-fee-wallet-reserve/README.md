# Idle-Fee Wallet Reserve

## Requirement

Prevent wallet-funded charging sessions from producing a negative balance when a charger can continue accruing an idle fee after charging stops.

- A wallet-funded start must reserve both the configured idle-fee cap and the normal charging allowance.
- A rejected start must tell the driver to top up the wallet or use a credit card.
- Credit-card charging is not subject to the wallet reserve.
- During charging, the backend must request a remote stop after 80% of the normal charging allowance has been consumed while preserving the remaining idle-fee exposure.
- Auto top-up remains available through the payment service before a low-balance stop is issued.
- Pricing and balance decisions are backend-owned. Mobile and web clients only render the API result.

## Authoritative Inputs

| Input | Source | Default |
| --- | --- | --- |
| Minimum wallet allowance | `app.charging.minimum-wallet-balance` | `5.00` |
| Stop consumption ratio | `app.charging.low-balance-stop-threshold-ratio` | `0.80` |
| Idle fee enabled | Session pricing snapshot | `false` |
| Idle fee cap | Price-plan/session pricing snapshot | `50.00` when enabled and not configured |
| Accrued idle fee | Backend session calculation | `0.00` |

The pricing snapshot is resolved before payment authorization so the exact connector price plan controls the reserve.

## Start Decision

For a wallet-funded session:

```text
required start balance = minimum wallet allowance + idle fee cap
```

The idle component is zero when the charger has no idle fee.

Example:

```text
minimum allowance = $5.00
idle fee cap      = $50.00
required balance  = $55.00
```

- `$54.99`: reject with HTTP `409` and top-up/credit-card guidance.
- `$55.00`: allow the start, subject to the existing payment authorization and connector checks.
- Credit card: bypass this wallet-balance rule.

The payment authorization hold uses the same required start balance. This prevents concurrent session starts from reserving the same wallet funds.

## Runtime Decision

The payment service evaluates projected wallet balance as:

```text
projected wallet balance = wallet balance - current projected session charge
```

The dynamic reserve sent by session-service is:

```text
safety floor = minimum wallet allowance * (1 - stop consumption ratio)
remaining idle exposure = max(idle fee cap - accrued idle fee, 0)
runtime reserve = safety floor + remaining idle exposure
```

For a `$55` wallet, `$5` allowance, 80% consumption ratio, and `$50` idle cap:

```text
safety floor            = $1.00
remaining idle exposure = $50.00
runtime reserve         = $51.00
```

The session remains eligible through `$4.00` of projected charging cost. Once projected cost exceeds that boundary, payment-service first attempts configured auto top-up. If the balance is still insufficient, session-service requests a low-balance remote stop and publishes `CHARGING_LOW_BALANCE_STOP`.

After charging stops, accrued idle fees reduce the remaining idle exposure by the same amount. This avoids reserving an idle fee twice while preserving enough balance for the unaccrued portion of the cap.

## Settlement Safety

- Idle fee remains capped by the session's snapshotted `idleFeeMaxAmount`.
- Total session cost remains capped by the session price-plan cap.
- Wallet settlement retains its existing negative-balance rejection.
- The new start and runtime guards reduce the chance of reaching settlement with insufficient funds; settlement remains the final invariant.

## Service Flow

1. Session-service receives the authenticated start request.
2. Session-service resolves and snapshots connector pricing, including idle settings and caps.
3. Session-service calculates the required wallet start balance.
4. Payment-service returns wallet state and creates an authorization hold for the calculated reserve.
5. Session-service starts the OCPP transaction only after payment eligibility succeeds.
6. Meter values and idle ticks update projected cost.
7. Session-service sends projected charge and dynamic reserve to payment-service.
8. Payment-service attempts auto top-up when configured and needed.
9. Session-service requests remote stop and publishes the low-balance event when funds remain insufficient.
10. Idle fees accrue only to their configured cap, then final settlement debits the wallet.

## Acceptance Checks

- [x] Idle-fee charger with `$50` cap requires `$55` for wallet start.
- [x] `$54.99` is rejected and `$55.00` is the accepted boundary.
- [x] Charger without idle fees retains the `$5` start requirement.
- [x] Runtime reserve is `$51` before idle fees accrue.
- [x] Runtime reserve falls to `$39` after `$12` of idle fees accrue.
- [x] Credit-card starts are unaffected.
- [x] Unit coverage protects the formulas and boundaries.
- [x] JMeter regression covers rejection below cap plus allowance.
- [ ] TeamCity build and deployed API validation completed.
