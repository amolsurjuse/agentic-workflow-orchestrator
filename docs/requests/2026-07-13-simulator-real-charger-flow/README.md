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
- The HMI treated `idleFeeEnabled` as if idle charging had already begun, so an idle-capable tariff could render "unplug required" during normal energy delivery.
- HMI Stop sent the final OCPP stop immediately and painted the connector Available even though the simulated cable was still connected.
- The wait-for-unplug transition updated only simulator memory. Without a `SuspendedEV` StatusNotification, session-service remained `CHARGING` and environment synchronization correctly restored that backend state.
- The periodic telemetry loop treated every active transaction as charging. After suspension it emitted `Charging` plus another meter value, causing session-service to resume the transaction.
- The card-present end-session intent existed only in simulator memory. Environment synchronization replaced it with a backend `SUSPENDED` projection that could not distinguish an EV pause from an ended session awaiting physical unplug, allowing the connector to return to `Charging`.
- The HMI fell back to the connector's configured maximum power when a suspended transaction had no live power value, incorrectly showing 150 kW after energy delivery ended.
- Production disables Liquibase and relies on Hibernate schema updates. Adding a non-null boolean without a database default failed for historical rows, so the unplug-state rollout requires an idempotent `DEFAULT false NOT NULL` database migration.
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
- End-session intent is explicit across the whole path. OCPP 1.6 carries `EndSessionRequested` in `StatusNotification.info`; OCPP 2.0.1 carries `customData.endSessionRequested=true`; OCPP service forwards it; session-service persists `unplug_required_to_stop`; and the active-session projection returns it to the simulator.
- Environment reconciliation preserves a local wait-for-unplug transition while the backend projection catches up. Once persisted, the backend flag forces `SuspendedEV`, zero power, and suspended transaction state even across simulator restarts.
- The HMI renders live power only while the connector is actively charging. Suspended and unplug-required states display `--` instead of configured maximum power.
- Periodic charging telemetry is disabled for suspended, finishing, stopped, completed, and unplug-required transactions, preventing energy growth or an accidental resume while the cable awaits removal.

## Test Coverage

- Angular: available state hides authorization methods; Preparing shows all three; component guards authorization before cable connection; idle-capable charging stays Charging; HMI Stop requests the wait-for-unplug transition.
- Simulator Go tests: RFID accept/reject, card cable precondition, card metadata, PnC OCPP 1.6 accepted and rejected flows, cable lifecycle, environment-import preservation, the pre-authorization reconciliation race, `SuspendedEV` propagation to the CSMS, and suspended-transaction telemetry suppression.
- OCPP tests: ISO 15118 DataTransfer envelope, native 2.0.1 PnC response, session client PnC context.
- OCPP tests also cover OCPP 1.6 and 2.0.1 end-session markers and propagation to session-service.
- Session tests: complete service regression suite, including persisted unplug-required state, active projection, charging, idle, fee-cap, receipt, and URL behavior.

## Production Acceptance

- TeamCity simulator build 37 completed successfully and image `amolsurjuse/ocpi-simulator:37` was promoted through GitOps.
- Production HMI pricing and physical-state controls were verified on the isolated `EH-US-CHG-0799` test charger.
- An unknown RFID remained in Preparing and displayed an authorization rejection without creating a transaction.
- An unknown eMAID and contract certificate remained in Preparing and displayed a Plug & Charge authorization rejection without creating a transaction.
- A contactless card created a session with `paymentMethod=CARD_PRESENT`, `authMethod=CREDIT_CARD`, and no security-code requirement.
- Stop transitioned the connector to `SuspendedEV` and the backend session to `SUSPENDED`. The meter stayed unchanged for more than two configured telemetry intervals.
- Physical unplug completed the backend session, cleared the persisted cable marker and active transaction, and returned the connector to Available.
- Follow-up acceptance for the card-session status bounce used simulator build 38, OCPP service build 20, and session-service build 69. All TeamCity builds passed and the corresponding production workloads were healthy in Argo CD.
- Session `a2d36bf4-069a-448b-b359-3c9f764a2ec1` on isolated charger `EH-US-CHG-0799` started as `CARD_PRESENT` / `CREDIT_CARD` with no security-code requirement. After End session, ten uncached reads over 40 seconds remained `SuspendedEV` / `SUSPENDED`, `unplugRequiredToStop=true`, power null, and meter 530 Wh. No reconciliation cycle returned the connector to Charging.
- The HMI remained on `Session complete` / `Unplug to finish`, showed charging power `--`, and exposed exactly one `Confirm vehicle unplugged` action. Confirming unplug completed the database session with `EV_DISCONNECTED`, cleared the flag and active transaction, and returned the connector to Available.
- The originally reported session `dbce0e31-08ba-4a05-a380-862817ade3d2` on `EH-US-CHG-0001` predated the durable marker. Reissuing its end-session intent through the public simulator contract migrated it to the persisted unplug-required state; the reported URL now renders the same stable unplug screen without completing the user's physical-unplug action.

## Interoperability Boundary

The simulator treats the configured contract certificate reference as the certificate assertion passed to the CSMS and requires an active `E_MAID` ID token. It does not perform local X.509 chain or OCSP cryptographic validation. Production-grade certificate-chain, revocation, and root-store simulation remains a separate ISO 15118 PKI capability and must not be represented as implemented.

## Reference

- Open Charge Alliance, [Using ISO 15118 Plug & Charge with OCPP 1.6](https://openchargealliance.org/ocpp-info-whitepapers/using-iso-15118-plug-charge-with-ocpp-1-6/)
