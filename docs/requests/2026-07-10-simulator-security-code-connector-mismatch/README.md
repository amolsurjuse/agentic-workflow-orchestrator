# Simulator Security Code Connector Mismatch

## Request

For session `0190e4f6-5e30-47f2-b5c1-63644a3b8d01`, simulator security-code verification reported that the code did not match the selected connector.

## Root Cause

The simulator HMI operates on local OCPP connector numbers such as `1`, while session-service stores and validates against the physical connector reference such as `CON-US-0131`. When the simulator sent the numeric connector number during verification, session-service rejected the request as a connector mismatch.

## Implementation

- Updated the simulator UI to send the selected connector reference for security-code verification.
- Added backend normalization in the simulator proxy so numeric connector IDs are translated to connector refs before calling session-service.
- Added a regression test proving `connectorId: "1"` is proxied as `connectorId: "CON-SFO-001"` when the simulator has connector metadata.

## Validation

- `go test ./internal/app` passed.
- Angular production build passed.
