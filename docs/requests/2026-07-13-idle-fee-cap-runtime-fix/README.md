# Idle Fee Cap Runtime Fix

## Request

Session `13f57c30-d21b-4b56-be9b-0c9ec122a5c3` on connector `CON-US-0231` continued to report a larger idle fee on every SSE update even though the pricing design requires an idle-fee cap.

## Production Evidence

- Session status: `SUSPENDED`
- Connector idle rate: `3.00 USD/min`
- Persisted overall session cap: `100.00 USD`
- Persisted idle-fee cap: `NULL`
- Pricing component cap: `50.00 USD`
- OCPI connector tariff: `ElectraHub USA Demo Tariff 231`, with an idle rate but no cap in the connector search document

## Root Cause

The session service combines two policy sources:

1. OCPI connector tariff supplies whether idle charging applies and the connector-specific rate.
2. Pricing service supplies configurable idle and total-session caps.

When the OCPI lookup succeeded, the start flow retained its rate but skipped the pricing service idle cap. The total cap was still copied, which explains why the session row had `session_max_amount = 100` while `idle_fee_max_amount` remained null. SSE calculates its separate idle-fee field from the session snapshot, so that field had no maximum.

## Correct Ownership

| Concern | Owner | Session snapshot behavior |
| --- | --- | --- |
| Idle fee enabled | OCPI connector tariff, pricing fallback | Copied at session start |
| Idle fee rate | OCPI connector tariff, pricing fallback | Copied at session start and not changed mid-session |
| Grace period | Connector policy or pricing fallback | Copied at session start |
| Idle fee maximum | Pricing plan | Always merged even when an OCPI tariff exists |
| Total session maximum | Pricing plan | Always merged |
| Resilience defaults | Session service configuration | Used only when a required cap cannot be resolved |

## Implementation

- Start flow now preserves OCPI terms while independently merging pricing caps.
- The start request's connector type is used for pricing-plan resolution when available.
- Defaults are explicit configuration:
  - `SESSION_DEFAULT_IDLE_FEE_CAP=50.00`
  - `SESSION_DEFAULT_SESSION_CAP=100.00`
- An active idle session with a missing cap performs one recovery lookup on its next Redis-scheduled tick.
- The recovered cap is persisted with the session. Later minute ticks use only the local snapshot, avoiding repeated policy calls and additional latency.
- If pricing is temporarily unavailable, the configured fail-safe cap prevents unbounded charging. A configured pricing cap always takes precedence.

## Cost And SSE Rules

```text
wholeIdleMinutes = floor(max(0, billableIdleSeconds) / 60)
rawIdleFee = idleFeePerMinute * wholeIdleMinutes
reportedIdleFee = min(rawIdleFee, idleFeeMaxAmount)
reportedSessionTotal = min(calculatedSessionTotal, sessionMaxAmount)
```

Elapsed idle time continues to increase after the monetary cap is reached. The idle fee and total cost do not increase beyond their respective caps.

## Performance Notes

- New sessions resolve and persist policy once during start, as before.
- Healthy active sessions make no additional pricing calls during idle ticks.
- Only legacy or partially persisted sessions with a missing cap invoke recovery.
- Redis continues to coordinate due ticks and locks between session-service replicas.

## Verification

- Unit test: pricing caps merge without replacing the connector idle rate.
- Unit test: configured defaults heal a missing active-session cap.
- Unit test: disabled idle fees do not receive an idle cap.
- Unit test: idle amount remains capped after elapsed time exceeds the maximum.
- Production acceptance:
  - current session row receives `idle_fee_max_amount = 50.0000`;
  - active-session API/SSE reports `idleFeeAmount <= 50.00` across consecutive ticks;
  - `idleSeconds` may continue increasing;
  - overall estimated cost remains at or below `100.00`.

