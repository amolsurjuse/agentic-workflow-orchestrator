# Nearby Charger Distance Units

## Request

Show the distance from the driver to each charger in the nearby charger list. US chargers must display miles; European chargers must display kilometers.

## Scope

- `driver-portal-ios`
- `driver-portal-android`
- Charger GraphQL response contract verification

No backend schema change was required. The charger GraphQL schema and production API already expose the charger's ISO `countryCode`.

## Unit Rule

Distance units are selected from the charger market, not solely from the device locale:

- `US`: miles (`mi`)
- Every other known country, including European countries: kilometers (`km`)
- Missing country: infer the two-letter country from the OCPI location or charger identifier
- No explicit or inferred country: use the device region as the final fallback

Distances below one tenth of the selected unit display as `< 0.1 mi` or `< 0.1 km`. Distances below 10 units display one decimal place; longer distances display as whole units.

## iOS Implementation

Commit: `21dad1a` (`feat: localize nearby charger distance units`)

- Added `countryCode` to `OcpiCharger` and `StationLocation`.
- Requested `countryCode` in charger list, search, and detail GraphQL operations.
- Preserved country metadata while grouping chargers by OCPI location and while refreshing station details.
- Replaced the fixed kilometer formatter in `NearbyChargerRow` with station-aware distance formatting.
- Kept cached stations compatible by decoding `countryCode` as optional and inferring it from OCPI identifiers when absent.

## Android Implementation

Commit: `e627201` (`feat: show localized nearby charger distances`)

- Added location permission handling and current-location acquisition.
- Uses the existing nearby-station endpoint after a driver location is available.
- Added optional station `countryCode` support with OCPI identifier fallback.
- Replaced raw coordinate text in charger cards with driver-to-station distance.
- Added pure Haversine distance calculation and locale-aware number formatting.
- Added unit tests for US, EU, and cached-station country inference.

## Validation

- Production GraphQL query returned `countryCode: "US"` for an OCPI charger.
- Android `testDebugUnitTest` passed all three distance tests.
- Android `assembleDebug` completed successfully.
- Android `lintDebug` completed successfully.
- `git diff --check` passed for iOS and Android before commit.
- Xcode is unavailable in the Windows workspace, so an iOS simulator build could not be run locally.

## Acceptance Criteria

- [x] Nearby charger rows show distance when driver location is available.
- [x] US charger distances use miles.
- [x] European charger distances use kilometers.
- [x] Unit selection follows charger country even when the device locale differs.
- [x] Older cached station records remain compatible.
- [x] Android requests location permission and refreshes nearby stations.
- [x] iOS and Android changes are pushed to `develop`.
