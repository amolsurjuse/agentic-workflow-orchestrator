# Admin Connector Mobile View Fix

## Request

The admin portal connector list showed search and action controls on mobile, but no connector data.

## Root Cause

The global responsive CSS hides `.subscription-table-wrap .data-table` below 768px and expects a `.subscription-card-list` mobile fallback. `ConnectorsPage` rendered only the desktop table, so the loaded connector records were hidden on phones.

## Implementation

- Added a mobile card list to `ConnectorsPage`.
- Kept the desktop connector table unchanged.
- Mobile cards show connector ID, charger, status, EVSE UID, standard, format, power, tariffs, updated date, and the same view/edit/configuration actions.
- Updated the production admin portal image tag in `k8s-platform`.

## Validation

- Ran the admin portal production build with `npm.cmd run build`.
- Deployed `amolsurjuse/admin-portal-ui:20260709-connector-mobile-cards`.
- Verify on mobile width that connector data appears as cards instead of a hidden table.
