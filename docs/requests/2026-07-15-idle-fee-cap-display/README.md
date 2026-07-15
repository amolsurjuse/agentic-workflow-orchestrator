# Idle Fee Display Exceeded Backend Cap

## Request

Investigate why the active charging screen displayed an idle fee above the configured `$50.00` cap for session `48a54ddc-1526-42ed-a1d4-dd52eccde62a` on `EH-US-CHG-0301 / CON-US-0301`.

## Production Evidence

The session snapshot stored in PostgreSQL contained:

- Currency: `USD`
- Idle fee rate: `$1.00/minute`
- Idle fee cap: `$50.00`
- Overall session cap: `$100.00`

The live Redis projection contained:

- `idleFeeAmount: 50.00`
- `estimatedCost: 58.0968`
- `idleSeconds: 3333`

The backend therefore capped the idle-fee component correctly. The larger value was the total discounted session cost, not an idle fee above the cap.

## Root Cause

The iOS active charging screen independently calculated a live idle fee from elapsed idle seconds and the per-minute rate. The active-session API did not expose the pricing plan's idle-fee cap, so this client-side projection continued increasing after the backend amount reached `$50.00`.

This duplicated billing business logic in the presentation layer and allowed the displayed amount to diverge from the amount used for settlement.

## Ownership Boundary

`session-service` is the sole authority for:

- billable idle seconds and whole-minute policy;
- grace-period handling;
- idle fee calculation;
- idle fee cap enforcement;
- overall session cap enforcement;
- subscription and discount application;
- the current total session cost.

Mobile and web clients must render the authoritative amounts returned by the active-session API or SSE stream. They may animate elapsed wall-clock time for presentation, but they must not derive a monetary amount from time and rate.

## Changes

### session-service

- Added `idleFeeMaxAmount` to the active-session REST/SSE contract.
- Added the cap to Redis map reconstruction and Elasticsearch current-session projections.
- Added a regression test proving Redis reconstruction preserves the cap.

### driver-portal-ios

- Removed client-side idle-fee calculation.
- Displays only the backend `idleFeeAmount`.
- Displays `idleFeeMaxAmount` as pricing metadata.
- Preserves the cap across REST/SSE reconciliation and legacy meter-event fallback.

## Validation

- [x] Production database snapshot verified.
- [x] Production Redis projection verified at the `$50.00` cap.
- [x] Backend tests passed: 62 tests, zero failures.
- [x] Backend change pushed to `develop`: `01d16c8`.
- [x] iOS changes pushed to `develop`: `7dd8a9b`, `26ddd88`.
- [x] TeamCity backend image build `#79` completed successfully.
- [x] Backend image `amolsurjuse/session-service:79` deployed; Argo is synced and healthy.
- [x] Production active-session projection verified with `idleFeeAmount: 50.00` and `idleFeeMaxAmount: 50.00`.
- [ ] iOS compiled through an Apple/Xcode build environment.
