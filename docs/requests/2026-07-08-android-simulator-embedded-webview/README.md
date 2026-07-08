# Android Simulator Link Embedded Web View

## Request

Apply the same in-app simulator behavior to the Android driver portal that was added to iOS.

## Implementation

- Removed the active charging simulator handoff to `Intent.ACTION_VIEW`.
- Updated the active charging simulator panel to open a full-screen in-app Compose dialog.
- Embedded the simulator with Android `WebView`.
- Enabled JavaScript and DOM storage so the Angular simulator UI can run inside the app.
- Added URL normalization for legacy simulator URLs shaped like `/ocpp-simulator-ui/?chargerId=...&connectorId=...&sessionId=...`.
- The normalized URL targets the single-page simulator connector route:
  - `/#charger/{chargerId}/connector/{connectorId}?sessionId={sessionId}`

## Files

- `C:\development\project\driver-portal-android\app\src\main\java\com\electrahub\driverportal\MainActivity.kt`
- `C:\development\project\driver-portal-android\app\src\main\java\com\electrahub\driverportal\ui\screens\ChargingScreen.kt`

## Validation

- `gradle --version` succeeded.
- `gradle :app:assembleDebug` initially failed because sandboxed Gradle could not establish its local loopback daemon connection.
- Retried with elevated execution; Gradle then failed because no Android SDK is configured:
  - `ANDROID_HOME` is empty.
  - `C:\development\project\driver-portal-android\local.properties` does not define `sdk.dir`.
  - Standard SDK paths checked on this host were not present.
