# Simulator HMI Motion

## Objective

Add purposeful motion to the on-charger HMI without changing the connector, authorization, transaction, stop, or unplug state machine. Motion must communicate the current physical state, remain stable on a phone display, and avoid unnecessary main-thread work.

## State Behavior

| HMI state | Motion cue | Driver meaning |
|---|---|---|
| Available | Expanding outer ring, small cable lift, centered readiness track | The connector is ready for a vehicle |
| Plugged / Preparing | Slow reader orbit, connected cable pulse, scanning track | The cable is detected and authorization is expected |
| Authorizing | Reader pulse and a restrained horizontal scan | The submitted credential is being verified |
| Charging | Rotating inner ring, energy pulse, three flowing track segments | Energy is actively moving to the vehicle |
| Suspended EV / EVSE | Breathing outer ring and paused track segments | The session remains active but energy flow is paused |
| Unplug required / Finishing | Expanding completion ring, cable release cue, reverse track | Energy delivery ended and the cable must be removed |
| Faulted | Infrequent alert movement and fault track flash | The connector cannot continue safely |
| Offline | Static muted presentation | No active network or charger operation is implied |

## Implementation Constraints

- The existing `HmiState` remains the single source of truth through the stage `data-state` attribute.
- Decorative orbit and energy-track elements have fixed dimensions, are `aria-hidden`, and never change layout size.
- Continuous effects primarily animate `transform` and `opacity`; live transaction polling and Angular state updates are unchanged.
- Authorization choices enter with a short stagger so the three methods remain visually distinct without delaying interaction.
- The existing color assigned to each operational state drives the visual cue; motion does not invent another status system.
- `prefers-reduced-motion: reduce` disables every new animation and transition while preserving all status text, controls, and state colors.

## Validation

- Angular component suite: 20 tests passed in Chrome Headless.
- Production Angular build: 474.53 kB raw, 113.34 kB estimated transfer.
- Desktop HMI validated at the normal browser viewport.
- Phone HMI validated at 390 x 844 for Available, Preparing, Charging, and Unplug required.
- Reduced-motion browser validation confirmed the computed animation names become `none`.
- A card-present test session on isolated charger `EH-US-CHG-0799` exercised Charging and Unplug required. Confirming physical unplug returned the connector to Available with no active transaction.

