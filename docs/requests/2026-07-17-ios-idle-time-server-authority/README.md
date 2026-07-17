# iOS Idle Time Server Authority

## Request

Correct the iOS live-charging idle timer. After idle duration began arriving from the backend, the screen could reset to an older time.

## Root Cause

The live-session reconciler protected the entire runtime state after an unplug-required transition. That also discarded fresh backend `idleSeconds` and `idleFeeAmount` values. The view then advanced the old value locally using its own timer. A delayed REST or SSE projection could therefore re-anchor the displayed duration to an older snapshot.

## Contract

- `idleSeconds` is the server-authoritative **billable** idle duration. The backend owns grace-period handling and any accumulated idle duration.
- `idleFeeAmount` is server-authoritative and already applies the configured cap.
- The iOS app must not derive either value from `idleStartedAt` or apply fee business logic.
- Within one unplug-required idle period, an out-of-order server projection may not reduce the displayed duration or fee.
- A terminal update remains authoritative and can clear or finalize the idle state.

## Implementation

1. Removed the local one-second idle timer from the active-charging UI.
2. Rendered the duration directly from the latest reconciled backend `idleSeconds` value.
3. Separated idle billing reconciliation from visual status/power stabilization.
4. During the same active idle period, retain the maximum received backend seconds and fee.
5. Reject a delayed idle payload whose `idleStartedAt` is older than the current idle period.

## Validation

- Simulate an idle session with a later server value followed by an older one; the displayed duration and fee must remain at the later values.
- Simulate a newer server update; the displayed duration and fee must advance.
- Simulate a terminal/unplug update; terminal state must be accepted and the normal receipt flow must continue.
- Build and run the iOS target in Xcode/TestFlight because the Windows workspace does not include the Apple Xcode toolchain.
