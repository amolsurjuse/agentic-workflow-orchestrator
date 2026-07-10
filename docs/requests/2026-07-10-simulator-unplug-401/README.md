# Simulator Unplug 401 Fix

## Request

Unplug from the simulator was returning HTTP 401.

## Root Cause

The simulator UI called the public ElectraHub session API directly to verify the simulator security code:

```text
https://api.electrahub.net/session/api/v1/sessions/{id}/simulator/verify-code
```

When the simulator is opened from a phone browser or web view, it does not reliably carry the authenticated driver API session. The public gateway can reject that call with 401 before the code validation reaches `session-service`.

## Implementation

- Added a same-origin simulator backend endpoint:

```text
POST /api/v1/sessions/{id}/simulator/verify-code
```

- The simulator backend proxies the validation to the internal session service using `SESSION_SERVICE_URL`.
- The UI now calls the simulator endpoint instead of the public session API.
- Added a backend regression test proving the proxy forwards the validation payload and service bearer token.
- Added `SESSION_SERVICE_URL` to the simulator chart config.

## Validation

- Angular production build passed.
- `go test ./internal/app` passed.
- Targeted proxy test passed.
- `go test ./...` was attempted but timed out after five minutes with no failure output; the touched package is covered.
