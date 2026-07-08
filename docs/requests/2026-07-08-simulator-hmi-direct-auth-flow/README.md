# Simulator HMI Direct Auth Flow

## Request

Remove the middle connector-detail step from the simulator driver flow. When a user selects a connector, open the HMI screen directly. Enhance HMI actions so RFID, credit card, and Plug & Charge collect the correct authorization details before triggering the OCPP simulator flow.

## Implementation

- Kept the charger/operator detail screen available for management tools.
- Changed the primary charger list row action to open the station HMI directly.
- Preserved the connector click path so connector links route directly to the station HMI:
  - `#station/{chargerId}/connector/{connectorId}`
- If a charger has multiple connectors, the HMI connector selector is shown on the HMI screen.
- Updated the HMI breadcrumb to return to the connector list instead of the operator console.
- Kept an explicit `Operator tools` action for users who still need charger management details.
- Refined HMI authorization dialog copy:
  - RFID asks for RFID auth ID.
  - Credit card asks for credit-card auth ID.
  - Plug & Charge asks for auth ID, EMID, VIN, and contract certificate.
- The existing simulator API behavior is preserved:
  - RFID/card submit tap authorization, then start charging.
  - Plug & Charge submits ISO 15118 details through the PnC start API.

## Files

- `C:\development\project\ocpi-simulator\ui\src\app\app.component.html`
- `C:\development\project\ocpi-simulator\ui\src\app\app.component.ts`

## Validation

- `npm.cmd run build` passed in `C:\development\project\ocpi-simulator\ui`.

## Production Deployment

- Committed and pushed simulator UI source:
  - `c726d62 Open simulator HMI directly from charger list`
- TeamCity UI deployment:
  - Build: `ElectraHub_OcppSimulatorUi_Build/925`
  - Image: `amolsurjuse/ocpi-simulator-ui:34`
  - Source revision: `c726d62ec44ca5c2aae48e65bce5f21e8897989f`
- TeamCity bundled simulator build:
  - Build: `ElectraHub_OcppSimulator_Build/926`
  - Image: `amolsurjuse/ocpi-simulator:23`
- Production image tags applied:
  - `ocpp-simulator-ui` -> `amolsurjuse/ocpi-simulator-ui:34`
  - `ocpp-simulator` -> `amolsurjuse/ocpi-simulator:23`
- Live validation:
  - `https://ocpp-simulator.electrahub.net/` now serves `main-UNC2K732.js`.
  - The live JS artifact SHA-256 matched the local production build artifact.

## Follow-up: Secure Unplug on Idle HMI

- Issue:
  - Idle-fee sessions showed `Idle - unplug required` on the HMI, but no unplug action was rendered for the suspended/idle state.
  - Unplug needed to require the 4-digit security code shown on the mobile active charging screen.
- Fix:
  - Added an HMI `suspended` state action that shows `Unplug EV`.
  - Added a `Security code required` dialog before unplug.
  - Added session-service verification call:
    - `POST /session/api/v1/sessions/{sessionId}/simulator/verify-code`
  - The dialog submits code, charger id, connector id, and action `UNPLUG`.
  - If no session id exists, local simulator-only sessions can still unplug after code entry.
- Validation:
  - `npm.cmd run build` passed in `C:\development\project\ocpi-simulator\ui`.
- Deployment:
  - Source commit: `06f552b Require security code before simulator unplug`
  - UI build: `ElectraHub_OcppSimulatorUi_Build/928`
  - UI image: `amolsurjuse/ocpi-simulator-ui:36`
  - Bundled simulator build: `ElectraHub_OcppSimulator_Build/929`
  - Bundled simulator image: `amolsurjuse/ocpi-simulator:24`
  - Production deployment updated:
    - `ocpp-simulator-ui` -> `amolsurjuse/ocpi-simulator-ui:36`
    - `ocpp-simulator` -> `amolsurjuse/ocpi-simulator:24`
  - Live validation:
    - `https://ocpp-simulator.electrahub.net/main-OZS3ZXMJ.js`
  - Confirmed live bundle contains `Security code required`, `Verify and unplug`, `verify-code`, and `UNPLUG`.

## Follow-up: Preserve Plugged HMI State and Skip Code Without Active Session

- Issue:
  - After `Plug in cable`, the HMI refreshed from synced charger data and returned to `Ready to charge`.
  - Unplug also asked for a security code even when no mobile-backed active charging session existed.
- Fix:
  - Added a short-lived connector status override in the simulator UI after a successful cable plug action.
  - The HMI now renders the effective connector status, so `Preparing` remains visible during background refreshes.
  - The override is cleared when charging starts, Plug & Charge starts, or unplug completes.
  - `Unplug EV` now opens the security-code dialog only when the active transaction has a session id from the backend.
  - If there is no active session id, unplug performs the normal simulator unplug immediately.
- Validation:
  - `npm.cmd run build` passed in `C:\development\project\ocpi-simulator\ui`.
