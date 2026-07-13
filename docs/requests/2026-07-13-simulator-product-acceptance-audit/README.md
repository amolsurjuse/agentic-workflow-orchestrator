# Simulator Product Acceptance Audit

## Request

Validate the production OCPP simulator as an EV product owner. Exercise the driver HMI and operator workflows manually, fix defects at their source, deploy the fixes, and repeat the production validation.

## Acceptance Perspective

The simulator must behave like a coherent EV charging product, not a collection of independent API controls. Acceptance covers:

- Driver clarity and mobile usability.
- Correct OCPP authorization and transaction sequencing.
- Live pricing disclosure before authorization.
- Consistent connector, transaction, and session state.
- Correct security behavior for registered and card-present sessions.
- Safe failure handling and recovery.
- Reachable operator controls without exposing them in the normal driver journey.

## Production Test Target

- URL: `https://ocpp-simulator.electrahub.net/#chargers`
- Test charger: `EH-US-CHG-0003`
- Connector: `1` / `CON-US-0003`
- Initial state: `CONNECTED`, `Available`, no active transaction.
- Existing active connectors were not modified.

## First-Pass Findings

| Area | Expected | Observed | Result |
| --- | --- | --- | --- |
| Fleet list | Location, network, connector, state, and active transaction are visible | 800 chargers loaded with searchable operational metadata | Pass |
| Direct driver navigation | Selecting a charger opens its HMI | List selection opened `#station/EH-US-CHG-0003` | Pass |
| Pricing | Tariff and policy are visible before authorization | Pricing API returned the plan, but the legacy station shell initially hid it | Fail |
| Cable connect/unplug | No-session unplug completes without a security code | `Available -> Preparing -> Available` completed immediately | Pass |
| RFID | Prompt for RFID and authorization identifiers before OCPP authorization | Full HMI submitted generated defaults immediately | Fail |
| Contactless | Prompt for a test card identifier and create a card-present session | Full HMI started immediately without collecting the identifier | Fail |
| Plug & Charge | Prompt for eMAID, contract certificate, token, and VIN | Full HMI started immediately with hardcoded defaults | Fail |
| Start-state consistency | HMI remains Charging after a successful start | Environment synchronization temporarily erased the local transaction | Fail |
| Card-present unplug | Unplug immediately without a security code | UI opened the security-code dialog during the synchronization gap | Fail |
| Heartbeat | Operator can send a heartbeat and runtime timestamp advances | `lastHeartbeatAt` advanced | Pass |
| Disconnect | Return one valid response and show coherent connection state | Response body mixed a 400 error with a 202 payload and displayed `invalid json` | Fail |
| Connector workbench | Operator can reach status, fault, meter, and PnC controls | Connector `Open` incorrectly routed back to the driver HMI | Fail |

## Root Causes

1. `startHmiAuthorization()` populated the prepared authorization form and immediately called `submitHmiAuth()`, making the form unreachable.
2. A newly created card-present transaction did not carry `paymentMethod`, `authMethod`, or `securityCodeRequired=false` until the environment session sync returned it.
3. Environment session reconciliation replaced fresh simulator transactions with an empty upstream snapshot during the service propagation window.
4. The disconnect UI sent `closeCode`, while the backend rejected unknown fields and then continued writing a success response after the decode error.
5. Operator connector navigation reused the driver station hash and made the connector workbench unreachable.

## Implemented Design Corrections

- Authorization buttons now open mode-specific credential dialogs.
- RFID requires an RFID tag and supports an authorization ID.
- Contactless requires a 12-19 digit test card ID.
- Plug & Charge requires eMAID, contract certificate ID, and PnC token; VIN remains visible.
- Card-present transactions carry payment/auth metadata and explicit no-code security behavior from creation.
- Card-present and `securityCodeRequired=false` sessions unplug directly without opening the code dialog.
- Recent local simulator transactions are preserved for 45 seconds while the environment session service catches up.
- Disconnect payload parsing returns immediately on malformed JSON and remains compatible with older clients that send `closeCode`.
- Driver list navigation still opens the HMI directly; operator connector `Open` now opens the connector workbench.

## Automated Verification

- `go test ./...`: pass.
- `npm.cmd run build`: pass.
- `npm.cmd test -- --watch=false --browsers=ChromeHeadless`: 12 tests pass.
- Commit: `12bc06f Fix simulator HMI authorization and state consistency`.

## Post-Deployment Matrix

This section is completed from the second production Chrome pass.

| Flow | Result | Evidence / Notes |
| --- | --- | --- |
| Production build and deployment | Pending | TeamCity `ElectraHub_OcppSimulator_Build` build `#30` / ID `982` started |
| Pricing on Available HMI | Pending | |
| Cable connect and no-session unplug | Pending | |
| RFID credential dialog and start | Pending | |
| Contactless dialog, stable Charging state, and code-free unplug | Pending | |
| Plug & Charge credential dialog and start | Pending | |
| Operator connector workbench | Pending | |
| Status and fault lifecycle | Pending | |
| Meter update | Pending | |
| Heartbeat | Pending | |
| Disconnect response and recovery | Pending | |
| Final connector state | Pending | Must be `Available`, connected, and have no active transaction |

## RFID Authorization Follow-Up

The first production audit exposed a critical authorization gap: the simulator sent an OCPP `Authorize` call but immediately returned `ACCEPTED` without waiting for `Authorize.conf`. This allowed any syntactically valid RFID value to advance to `StartTransaction`.

The corrected sequence is now:

1. The HMI submits the RFID to the simulator `/tap` endpoint.
2. The simulator sends OCPP `Authorize` through `web-socket-connector` and waits for the response with the same OCPP message ID.
3. `ocpp-service` calls `session-service /api/v1/sessions/authorize`.
4. `session-service` applies Redis, registered-token, group, OCPI, and offline-policy checks.
5. Only `Accepted` returns HTTP 200 and allows the UI to call `/charging/start`.
6. `Invalid`, `Blocked`, `Expired`, OCPP errors, bridge failures, and timeouts reject the HMI request. No transaction is created.

An additional Spring Boot 4 client incompatibility was found during acceptance: `ocpp-service` attempted to deserialize the authorization response into Jackson 2 `JsonNode`, which its HTTP converter could not handle. The client now uses a typed response record, preserving fail-closed behavior while restoring valid-RFID acceptance.

### Production Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Registered RFID | Pass | Temporary registered test token returned HTTP 200 `ACCEPTED`; token and Redis cache were deleted afterward |
| Unknown RFID | Pass | HTTP 403 with `RFID card is not authorized.` and result `INVALID` |
| Transaction safety | Pass | `EH-US-CHG-0003` remained `Available` with zero active transactions after rejection |
| OCPP correlation | Pass | Bridge received `Authorize.conf` with the same OCPP message ID before returning to the simulator |
| Timeout behavior | Pass | Automated test proves pending calls are removed and authorization fails closed |

### Released Components

- `web-socket-connector` commit `6c02a13`, TeamCity build `#15`, production image `15`.
- `ocpi-simulator` commit `2d0f003`, TeamCity build `#32`, production image `32`.
- `ocpp-service` commit `23ced06`, TeamCity build `#17`, production image `17`.
