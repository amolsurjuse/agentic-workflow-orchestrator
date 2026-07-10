# Sparky Charger Availability Context

## Request

On the iOS charger detail screen, Sparky answered that a charger was available while the screen showed it was occupied and charging. Verify whether the mobile app passes charger context to Sparky, ensure Sparky fetches and uses live charger state correctly, and show a thinking/writing indicator while Sparky is responding.

## Findings

- The iOS map tab always passed a plain map chat context from `MainTabView`, so the selected charger detail screen did not provide `chargerId`, `connectorId`, or `locationId` to Sparky.
- `ai-support-service` already collected live charger facts when charger context was present, but the question "Is this charger available?" fell through to the generic driver support response instead of using a deterministic charger availability answer.
- The iOS chat appended the assistant message only after `sendMessage` returned, leaving no visible thinking state during the initial request.

## Changes

- iOS now updates Sparky context when charger detail loads and when a connector is selected.
- iOS now inserts a pending assistant bubble immediately with "Sparky is checking live charger status..." while the backend request and stream are in progress.
- `ai-support-service` now detects charger availability questions and answers from live diagnostics deterministically. It reports unavailable when live facts show zero available ports, busy ports, charging/occupied/faulted status, or connector `available=false`.
- Added unit tests for busy and available charger responses.

## Validation

- Ran `mvn test` for `ai-support-service`: 11 tests passed.
- iOS compile was not available in the Windows workspace because `xcodebuild` and `swift` are not installed.

## Deployment

- `k8s-platform` prod image tag updated to `20260710-sparky-availability-context`.
