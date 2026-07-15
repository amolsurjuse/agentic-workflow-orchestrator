# Active Charging Station Display

## Request

Open the simulator station display directly from the iOS active charging screen instead of opening the charger or connector detail screen.

## Existing Flow

The session service returned simulator links in this form:

```text
https://ocpp-simulator.electrahub.net/#charger/{chargerId}/connector/{connectorId}?sessionId={sessionId}&securityCode={securityCode}
```

The `charger` hash route selects the simulator's connector-detail view. The simulator's HMI is owned by the `station` hash route, so the active charging action landed one screen before the intended driver interaction.

## Updated Contract

The session service now emits:

```text
https://ocpp-simulator.electrahub.net/#station/{chargerId}/connector/{connectorId}?sessionId={sessionId}&securityCode={securityCode}
```

The session and security-code query parameters remain inside the hash route. The simulator can therefore select the active connector and authorize unplug without displaying or asking the driver to re-enter the security code.

## Client Compatibility

The iOS active charging screen opens the station display inside its existing `WKWebView` sheet. Before opening the URL, it also converts legacy `#charger/...` links to `#station/...`. This covers active-session records or cached SSE projections created before the backend contract change.

Only the route is rewritten. Charger ID, connector ID, session ID, security code, host normalization, and in-app browser behavior are preserved.

## Validation

- [x] Confirmed `#station/{chargerId}/connector/{connectorId}` selects the simulator station HMI.
- [x] Updated the session-service URL builder and unit expectations.
- [x] Updated iOS legacy-link normalization.
- [x] Updated active charging action and in-app title to `Station Display`.
- [x] Session-service tests passed, including cached Redis URL compatibility.
- [x] TeamCity session-service build `#80` completed successfully.
- [x] Production deployed with `amolsurjuse/session-service:80` and Argo reported Synced/Healthy.
- [x] Production active-session API returned the `#station/...` link with session and security parameters intact.
- [x] Browser validation confirmed that the production link renders the station HMI and unplug action.
- [ ] Run iOS compilation and UI validation in an Apple/Xcode environment.
