# iOS Simulator Security Code URL Update

## Request

Update the iOS app so the simulator security code is passed in the simulator URL and no longer displayed on the active charging screen.

## Implementation

- Removed the visible four-digit simulator security code from the active charging simulator access panel.
- Kept the simulator access panel and open button visible when simulator access exists.
- Updated simulator URL normalization to append `securityCode` automatically.
- Preserved support for both current hash-route simulator links and legacy `/ocpp-simulator-ui` links.

## Validation

- Searched the active charging view to confirm visible `Security code` text and accessibility label were removed.
- Swift/Xcode validation could not be run in this Windows workspace because `swift`, `swiftc`, and `xcodebuild` are not installed.
