# iOS Live Charging State Stability

## Request

Prevent the Driver Portal iOS active-charging screen from fluctuating between `CHARGING` and `SUSPENDED`, and prevent cumulative energy and current power from briefly resetting when REST, SSE, and polling projections arrive out of order.

Reported charger context:

- Charger: `EH-US-CHG-0001`
- Connector: `CON-US-0001`
- Related session inspected: `3839ccd2-46be-4a2c-b515-3bbf6b94aacc`

## Flow

1. iOS loads `GET /session/api/v1/sessions/active`.
2. iOS opens `GET /session/api/v1/sessions/active/stream`.
3. The stream first sends a `SNAPSHOT`, followed by `SESSION_UPDATED` events from OCPP status and meter processing.
4. If SSE disconnects, iOS retains the visible session and starts REST polling while reconnecting.
5. OCPP meter and status events are independent. A delayed Redis/REST projection can therefore arrive after a newer meter projection.

## Investigation

The iOS view model replaced the complete `LiveChargingSession` for every REST, snapshot, session, legacy meter, status, and polling update. It preserved only the simulator link. Consequences for the same session were:

- A delayed projection with `energyDeliveredKwh = 0` replaced a higher cumulative energy value.
- A `CHARGING` projection with zero or temporarily missing power replaced the last measured charging rate.
- One low-power `SUSPENDED` projection immediately changed the screen even when the next meter update restored charging.
- Legacy meter/status handlers bypassed the normal session merge path.

The session-service already treats energy as cumulative by taking the maximum delivered energy during meter ingestion. The client must maintain the same invariant while combining projections.

Production history for the inspected session showed normal `Preparing -> Charging` OCPP status before remote stop. At investigation time the session was completed and the simulator connector was `Available`, so the client fix is validated with a deterministic event matrix rather than by mutating the completed production session.

## Design

`LiveChargingSessionReconciler` is the single state boundary for all live-session sources.

### Cumulative telemetry

- Energy never decreases for the same session ID.
- A new session ID resets telemetry normally.
- A stale projection cannot reduce the displayed cost along with regressed energy.
- Optional battery and time estimates retain their last known values when omitted.

### Power

- Positive incoming charging power is displayed immediately.
- A zero-power update that still says `CHARGING` retains the last positive charging rate.
- Confirmed suspended, unplug-required, finishing, and completed states display the incoming zero power.

### Status

- A non-terminal projection whose energy regresses cannot replace the newer status.
- For idle-fee sessions, `CHARGING -> SUSPENDED` without an unplug requirement must remain present for four seconds before it replaces a healthy charging state.
- Remote-stop/unplug-required suspension is immediate.
- Persistent suspension is accepted and shows the idle state.
- `SUSPENDED -> CHARGING` requires positive power when an idle period is active.
- Finishing and completed transitions are immediate.

### Coverage paths

The reconciler is used by:

- Initial active-session REST load
- SSE snapshot events
- SSE session events
- Receipt-preparing and terminal events
- Legacy meter-value events
- Legacy status events
- Polling fallback

## Verification

The reconciler was compiled and executed with Swift 6.0.3 in a Linux Swift container using the production model code. Eighteen assertions passed across:

- Stale zero energy and power
- Transient suspension
- Confirmed persistent suspension
- Stale charging update while idle
- Positive-power charging resume
- Remote-stop unplug-required suspension
- Terminal completion
- New-session reset

Full iOS application packaging still requires Xcode/macOS because SwiftUI, WebKit, and the iOS SDK are unavailable in the Windows workspace.

## Acceptance Criteria

- [x] Energy cannot reset within one session.
- [x] Charging power is retained during a delayed zero-power charging projection.
- [x] One transient idle-fee suspension does not flash the idle screen.
- [x] Persistent idle state still appears.
- [x] Remote-stop idle appears immediately.
- [x] Charging resumes when positive power returns.
- [x] Terminal transitions remain immediate.
- [x] Every live update path uses the same reconciliation behavior.
