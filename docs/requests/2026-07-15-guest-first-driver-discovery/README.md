# Guest-First Driver Discovery

## Product Goal

Open the driver application on charger discovery instead of requiring an
account before the driver can inspect the network. Authentication becomes a
clear transition into account and charging capabilities, not a prerequisite
for viewing public charger information.

This behavior must remain aligned across iOS and Android.

## Experience Contract

| Capability | Guest | Authenticated driver |
| --- | --- | --- |
| Open app on charger map/nearby view | Yes | Yes |
| Grant location permission | Yes | Yes |
| Search and browse nearby chargers | Yes | Yes |
| View live availability and connector status | Yes | Yes |
| View connector specifications and pricing | Yes | Yes |
| View distance and launch driving directions | Yes | Yes |
| Sign in or register | Yes | Not applicable |
| Start or stop charging | No control is rendered | Yes, subject to existing rules |
| Select wallet or stored card | No | Yes |
| View recently used chargers | No | Yes |
| View or change favorites | No | Yes |
| Dashboard, charging, payments, profile, notifications | No | Yes |
| Sparky account/session assistant | No | Yes |

## Navigation And State

1. The app performs its existing token bootstrap.
2. While bootstrap is unresolved, the existing preparation screen remains.
3. A valid restored session opens the normal authenticated tab experience on
   the Map tab.
4. No valid session opens the Map tab in guest mode.
5. The guest top bar provides a clear `Sign In` action. The authentication
   surface provides both Sign In and Register modes.
6. Successful authentication dismisses the authentication surface without
   discarding the current map context.
7. Logout returns to guest Map mode and clears account-only data.

## Public Data Contract

Guest discovery uses the existing anonymous endpoint:

```text
POST /charger/graphql
```

Only charger discovery fields are requested: charger/location identity,
coordinates, status, EVSE/connectors, connector specifications, and tariff
components. Guest requests do not call station, session, payment, user,
preference, notification, subscription, or AI endpoints.

The protected station endpoints currently return `401` without a token and
remain protected. Android must use the same charger GraphQL discovery contract
as iOS instead of weakening station-service access.

## Security Boundaries

- Hiding a button is not the authorization control. Session start/stop and all
  account APIs remain authenticated at the gateway and owner service.
- Guest UI does not invoke payment method loading, recent/favorite sync,
  notification registration, active-session streaming, or profile APIs.
- Guest UI does not persist recently viewed chargers or favorites.
- Guest UI never treats a missing session owner and missing user ID as an
  ownership match.
- Charger discovery requests omit user, wallet, card, subscription, and
  session-owner data.
- Authentication failures return to guest discovery rather than leaving a
  partially authenticated screen.

## iOS Design

- `RootView` renders `MainTabView` after bootstrap for both authenticated and
  guest states.
- `MainTabView` already limits guest tabs to Map and owns the authentication
  sheet.
- `StationMapView` receives an authentication callback and suppresses
  preference loading, recent recording, favorite controls, and account-only
  list modes for guests.
- Connector details continue to show specifications and tariffs. Payment
  methods and Start Charging are replaced by a Sign In/Register call to action
  for guests.
- Directions remain available to everyone.

## Android Design

- `DriverPortalApp` always renders its scaffold; guests see only the Map
  destination and Sign In action.
- Authentication is presented as a modal with Sign In/Register modes.
- `AppViewModel` loads public charger discovery during initialization and when
  guest location changes. Account refresh calls remain authentication-gated.
- `StationRepository` uses charger GraphQL and maps OCPI charger/location/EVSE/
  tariff data into the existing station model.
- Guest station cards show distance, connector state/specification, pricing,
  and Directions. Favorite and Start Charging controls are not rendered.

## Failure Behavior

- Location denial still loads a bounded charger list without geo arguments.
- Public discovery failure shows the existing retry/error state without
  navigating to login.
- Pricing unavailable is shown as unavailable; the client does not invent a
  price.
- Expired authenticated sessions fall back to guest Map mode after existing
  logout/session-clear handling.

## Validation

1. Fresh install and logged-out launch opens Map, not login.
2. Guest can grant/deny location and still browse chargers.
3. Guest can inspect availability, connector data, pricing, and directions.
4. Guest sees neither recent/favorite data nor controls.
5. Guest sees no Start Charging, wallet, stored cards, account tabs, or Sparky.
6. Sign In and Register are reachable from guest Map.
7. Successful authentication restores the full tab set and protected actions.
8. Logout returns to guest Map and removes account-only state.
9. iOS build and Android unit/build tasks pass.
10. Anonymous charger GraphQL succeeds while protected station/session/payment
    requests remain unauthorized.

## Implementation Status

Implemented locally on 2026-07-15:

- iOS now completes bootstrap into `MainTabView` for both guest and signed-in
  states and defaults to Map.
- iOS guest mode hides recent/favorite state, payment methods, Start Charging,
  account tabs, and session-owner data while retaining charger detail, pricing,
  and directions.
- Android now defaults to charger discovery, offers Sign In/Register in a
  modal, and requests push permission only after authentication.
- Android discovery now uses the public OCPI charger GraphQL contract and
  displays energy, time, session, and idle tariff components when supplied.
- Android guest cards expose Directions but do not render favorite or Start
  Charging controls.
- Android unit tests and debug APK assembly pass with JDK 21.
- The production anonymous-route matrix returned `200` for charger GraphQL and
  `401` for station list, active sessions, payment state, charger preferences,
  and notification inbox.

iOS source was statically reviewed in the Windows workspace. A signed iOS build
requires the macOS/TeamCity toolchain after the changes are committed.
