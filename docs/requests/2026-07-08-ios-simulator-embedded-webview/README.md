# iOS Simulator Link Embedded Web View

## Request

Open the simulator link from the active charging screen inside the iOS driver app instead of handing off to the external browser.

## Implementation

- Updated the active charging simulator access panel to present a SwiftUI sheet with an embedded `WKWebView`.
- Replaced the `openURL` browser handoff with an in-app simulator browser.
- Added URL normalization for older simulator URLs shaped like `/ocpp-simulator-ui/?chargerId=...&connectorId=...&sessionId=...`.
- The normalized URL points to the simulator single-page connector route:
  - `/#charger/{chargerId}/connector/{connectorId}?sessionId={sessionId}`
- Existing backend-provided hash-route URLs continue to load directly.

## Files

- `C:\development\project\driver-portal-ios\DriverPortalIOS\Views\Charging\LiveChargingView.swift`

## Validation

- Static inspection completed.
- `xcodebuild` validation could not be run in the current Windows workspace because the command is not installed.
