# Simulator Real-Charger Flow Review

## Objective

Make the simulator HMI behave like a public charging station rather than an operator test form. The connector's physical state is authoritative, every authorization method fails closed, and transaction/session metadata records how the driver actually authorized.

## Product State Model

| HMI state | Connector/OCPP state | Driver sees | Allowed actions | Forbidden actions |
|---|---|---|---|---|
| Offline | Disconnected or Unavailable | Station unavailable and support reference | Exit, select another connector | Plug, authorize, start |
| Faulted | Faulted | Fault reason and support reference | Exit, select another connector | Plug, authorize, start |
| Available | Available, no transaction | Live tariff and Connect cable | Connect cable | RFID, contactless, PnC, start |
| Vehicle connected | Preparing, no transaction | PnC, RFID, contactless and Release cable | Select one authorization method or unplug | Start without authorization |
| Authorizing | Preparing, request in flight | Method-specific progress | Wait | Duplicate submissions, connector switching |
| Authorization rejected | Preparing, no transaction | Specific rejection reason | Retry or choose another method | Create a transaction |
| Charging | Charging, active transaction | Energy, power, duration, tariff and stop | Stop session | Start another session |
| Idle / unplug required | SuspendedEV, active idle session | Idle fee, cap and unplug action | Unplug under the configured security policy | New authorization |
| Finishing | Finishing | Completion progress | Unplug when requested | New authorization |
| Complete | Available, no transaction | Session complete | Start a new physical flow | Reuse the completed transaction |

## Authorization Acceptance Matrix

| Method | Preconditions | Source of truth | Success | Rejection behavior | Session metadata |
|---|---|---|---|---|---|
| RFID | Connected charger, cable in Preparing, non-empty RFID | OCPP Authorize -> session-service ID token registry/cache | Start only after Accepted | Stay Preparing; show invalid/blocked/expired result | `RFID`, token owner when known |
| Contactless card | Connected charger, cable in Preparing, valid test card data | payment-service card-present authorization | Create payment hold and opaque payment token, then start | Stay Preparing; no transaction; show processor reason | `CREDIT_CARD`, `CARD_PRESENT`, masked card in payment records, no simulator security code |
| Plug & Charge 2.0.1 | Connected charger, cable in Preparing, eMAID and contract certificate reference | Native OCPP Authorize with `idToken.type=eMAID` -> session-service E_MAID token registry | Start after token and certificate status are Accepted | Stay Preparing; allow RFID/contactless fallback | `PLUG_AND_CHARGE`, `PLUG_AND_CHARGE`, E_MAID owner when known |
| Plug & Charge 1.6 | Same physical/contract preconditions | OCA ISO 15118 extension: `DataTransfer` vendor `org.openchargealliance.iso15118pnc`, message `Authorize` | StartTransaction uses eMAID as idTag only after wrapped authorization succeeds | Stay Preparing; allow fallback | Same as 2.0.1 |

## Defects Found

- The HMI exposed RFID, contactless, and PnC while the connector was still Available. Each route could start a transaction without a connected cable.
- Plug & Charge accepted every submitted eMAID/certificate and created a transaction without consulting the CSMS.
- The PnC flow did not distinguish OCPP 1.6's required ISO 15118 DataTransfer extension from OCPP 2.0.1 native authorization.
- PnC transactions did not persist payment method, authorization method, or token type, so downstream sessions could be classified as RFID.
- OCPP 2.0.1 Authorize responses used the OCPP 1.6 `idTagInfo` field.
- Blank RFID input silently became the fallback `SIMULATOR` token.
- Contactless/PnC request errors closed the credential dialog instead of preserving the connected state and allowing retry.
- Environment synchronization treated `Preparing` as a stale inferred session status. It could reset a physically connected cable to `Available` between plug-in and authorization, while the HMI still appeared connected.
- The HMI treated `idleFeeEnabled` as if idle charging had already begun, so an idle-capable tariff could render “unplug required” during normal energy delivery.
- HMI Stop sent the final OCPP stop immediately and painted the connector Available even though the simulated cable was still connected.
- The wait-for-unplug transition updated only simulator memory. Without a `SuspendedEV` StatusNotification, session-service remained `CHARGING` and environment synchronization correctly restored that backend state.
- The periodic telemetry loop treated every active transaction as charging. After suspension it emitted `Charging` plus another meter value, causing session-service to resume the transaction.
- Tests asserted button presence but did not cover physical state gating, PnC rejection, or method metadata.

## Implemented Behavior

- Available HMI presents one physical action: Connect cable.
- Preparing HMI presents PnC, RFID, contactless, and Release cable together.
- UI and backend both enforce the cable precondition for driver HMI starts.
- RFID authorization and transaction creation are one backend operation for the HMI, eliminating the client-side gap between an accepted credential and the start command.
- Card authorization happens only after the physical precondition, preventing unnecessary payment holds.
- PnC accepts an eMAID and contract certificate reference, uses the eMAID as the protocol token, waits for CSMS authorization, and fails closed.
- OCPP 1.6 and 2.0.1 PnC authorization use their correct protocol shapes.
- Started PnC transactions carry `PLUG_AND_CHARGE` method and `eMAID` token metadata into session-service.
- Rejected authorization leaves the connector Preparing and reopens the method dialog with the backend reason.
- Blank RFID credentials are rejected instead of substituted.
- The connector persists `cableConnectedAt` as physical state. Charger imports preserve it, and active-session reconciliation atomically keeps the EVSE Preparing until an explicit cable release clears it.
- Idle-fee capability and active idle state are separate: an enabled tariff remains in Charging until the transaction is suspended or explicitly marked unplug-required.
- HMI Stop is two-phase. It stops energy and enters unplug-required without sending the final OCPP stop; physical unplug then clears the cable state and completes the transaction. Card-present sessions bypass the security-code prompt but still require the unplug action.
- Entering wait-for-unplug emits OCPP `SuspendedEV`, allowing the CSMS and session-service connector index to become authoritative before the next environment reconciliation.
- Periodic charging telemetry is disabled for suspended, finishing, stopped, completed, and unplug-required transactions, preventing energy growth or an accidental resume while the cable awaits removal.

## Test Coverage

- Angular: available state hides authorization methods; Preparing shows all three; component guards authorization before cable connection; idle-capable charging stays Charging; HMI Stop requests the wait-for-unplug transition.
- Simulator Go tests: RFID accept/reject, card cable precondition, card metadata, PnC OCPP 1.6 accepted and rejected flows, cable lifecycle, environment-import preservation, the pre-authorization reconciliation race, `SuspendedEV` propagation to the CSMS, and suspended-transaction telemetry suppression.
- OCPP tests: ISO 15118 DataTransfer envelope, native 2.0.1 PnC response, session client PnC context.
- Session tests: complete service regression suite, including existing charging, idle, fee-cap, receipt, and URL behavior.

## Interoperability Boundary

The simulator treats the configured contract certificate reference as the certificate assertion passed to the CSMS and requires an active `E_MAID` ID token. It does not perform local X.509 chain or OCSP cryptographic validation. Production-grade certificate-chain, revocation, and root-store simulation remains a separate ISO 15118 PKI capability and must not be represented as implemented.

## Reference

- Open Charge Alliance, [Using ISO 15118 Plug & Charge with OCPP 1.6](https://openchargealliance.org/ocpp-info-whitepapers/using-iso-15118-plug-charge-with-ocpp-1-6/)
