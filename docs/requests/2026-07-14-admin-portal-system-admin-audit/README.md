# Admin Portal System-Admin Audit

Date: 2026-07-14  
Environment: `https://admin-portal.electrahub.net/`  
Role: `SYSTEM_ADMIN`  
Method: authenticated Chrome walkthrough at desktop and 390 x 844 mobile viewports, followed by source and API contract inspection.

## Objective

Validate every system-admin route and the list, view, add, edit, filter, pagination, configuration, and responsive states. Record all findings before changing code, then deliver one coordinated fix and repeat the production walkthrough.

## Route Coverage

| Area | Route | Production result | Action coverage |
| --- | --- | --- | --- |
| Dashboard | `/dashboard` | Loaded live analytics | Period controls, leaderboard, driver sessions, Sparky |
| Users | `/users` | Loaded 10 users | Search, view, edit |
| Admin users | `/admin-users` | Loaded 1 admin | Add, view, edit |
| RBAC | `/rbac/policy` | Loaded | Route map, JSON preview, templates |
| Enterprise | `/charger/enterprise` | Loaded 3 | Add, view, edit |
| Network | `/charger/network` | Loaded 5 | Add, view, edit |
| Location | `/charger/location` | Loaded 100 | Add, view, edit |
| Network operator | `/general/network-operator` | Loaded 3 | Add, view, edit |
| Station make | `/general/charge-station-make` | Loaded 8 | Add, view, edit |
| Port level | `/general/port-level` | Loaded 10 | Add, view, edit |
| Station model | `/general/charge-station-model` | Loaded 12 | Add, view, edit |
| Charger groups | `/charger-management/charger-groups` | Loaded 2 | Add, view, edit |
| Chargers | `/charger-management/chargers` | Loaded 100 | Add, view, edit |
| EVSEs | `/charger-management/evses` | Loaded 100 | Add, view, edit |
| Connectors | `/charger-management/connectors` | Loaded 100 of 1,053 | Add, view, edit, charger configuration |
| Site controllers | `/network-operator/site-controller` | Loaded 4 | Add, view, edit |
| Pricing | `/pricing` | Loaded 10 | Add, view, edit |
| Subscriptions | `/subscriptions` | Loaded 1 | Add, view, edit, allocations, utilizations, audit |
| Allocations | `/allocations` | Loaded 10 | Grant quota, filters |
| Utilizations | `/utilizations` | Expected search-first state | User lookup, preview charges |
| Charging sessions | `/charging/sessions` | Loaded 3 active and 1,721 completed | Tabs, filters, paging, receipt; production stop not submitted |
| Notifications | `/notifications` | Loaded 14, 8 unread | Inbox and reader states; read mutation not submitted |
| Audit logs | `/audit-logs` | Loaded 15 per page | Filters and paging |

All 23 routes rendered without browser console errors or warnings during the initial pass.

## Confirmed Findings

### P0: Production configuration screens use browser-only mock data

The following pages import local mock collections and mutate React state only. Add/edit changes disappear after refresh and are never shared with other admins:

- Network operators
- Charge station makes
- Port levels
- Charge station models
- Site controllers

Required fix: persistent charger-management-service tables and CRUD APIs, API-backed UI pages, validation, and audit-friendly timestamps.

### P0: Several edit actions create duplicates instead of updating

The Charger Group, Charger, EVSE, and Connector Edit buttons prefill an add form. The title and submit action remain Create/Add, and the inventory APIs do not expose the required update operations. Site Controller Edit is a no-op. Regular User Edit opens a read-only profile.

Required fix: explicit create/edit modes, stable record identity, PUT endpoints, and a real regular-user edit form.

### P1: Several View buttons do not open a record

Enterprise, Network, Location, Charger Group, Charger, EVSE, and Connector View merely replace the search text with the identifier. Site Controller View does nothing.

Required fix: a read-only record detail surface with an intentional Back action. Search must remain search.

### P1: Inventory paging and totals are misleading

Locations, Chargers, EVSEs, and Connectors request 100 records and provide no way to access later pages. Production has 1,053 connectors. Mobile renders all 100 loaded records as one very long card list. “Active” summary values count only the current loaded slice while appearing to be global totals.

Required fix: server-backed 25-row pagination, page-aware request offsets, accurate range/total text, and honest page-scoped enabled counts unless the backend supplies global enabled totals.

### P1: Sparky does not receive live page data

On the dashboard, the assistant context is only `dashboard`. Asking “What is the total revenue for the current dashboard period?” returned a generic explanation even though the visible value was `USD 72,127.03`.

Required fix: pass a bounded, typed page context containing the selected filters and visible live metrics. Preserve the pending/thinking state until the response completes and clearly report unavailable data rather than inventing an answer.

### P1: Charging sessions overflow on phone layouts

At 390 px, `/charging/sessions` has a 409 px document width. The tab/count region is clipped and the Sparky launcher overlaps a connector filter control.

Required fix: wrapping tab controls, constrained badges, `min-width: 0` on grid children, no page-level horizontal overflow, and safe-area-aware assistant placement.

### P2: Form controls lack reliable accessible names

Many add/edit inputs are visually labelled but expose unnamed textbox/combobox nodes in the Chrome accessibility tree. This affects keyboard/screen-reader navigation and makes automated validation brittle.

Required fix: explicit `id` plus `htmlFor`, or an equivalent `aria-label`, in shared and page-specific form fields.

### P2: Action semantics are unclear

Some actions labelled View behave like Filter and some labelled Edit behave like Create. The connector configuration dialog contains destructive commands (reset and decommission) alongside ordinary controls without a consistent confirmation boundary.

Required fix: align labels with behavior, isolate destructive actions, and retain explicit confirmation for production mutations.

## Implementation Boundaries

- Preserve existing enterprise/network/location, pricing, subscription, session, notification, and RBAC behavior.
- Extend the existing charger-management-service admin ownership boundary instead of introducing another service.
- Work with the unpushed charger configuration command commit already present on `develop`; do not overwrite it.
- Use existing UI components and styling patterns.
- Do not create, edit, stop, reset, or decommission production records during validation unless separately confirmed.

## Planned Validation

- Admin portal typecheck, unit tests, and production build.
- Charger management service tests and package build.
- API validation for every new CRUD and update contract.
- Re-run the 23-route Chrome matrix as `SYSTEM_ADMIN`.
- Re-run add/view/edit surfaces without submitting production mutations.
- Confirm Connectors can page beyond row 100 and display an accurate range.
- Confirm dashboard Sparky answers from the same live metric shown on screen.
- Confirm 390 x 844 layouts have no horizontal overflow or covered controls.
- Confirm browser console remains free of errors and warnings.

## Completion Checklist

- [x] Route inventory completed
- [x] Desktop walkthrough completed
- [x] Mobile walkthrough completed
- [x] Source/API gap analysis completed
- [x] Issue set frozen before implementation
- [x] Persistent reference-data APIs implemented
- [x] Real inventory view/edit flows implemented
- [x] Pagination and totals corrected
- [x] Sparky page context corrected
- [x] Mobile and accessibility defects corrected
- [x] Automated builds/tests passed
- [x] Production deployment completed
- [x] Production Chrome re-audit passed

## Implementation And Production Verification

Completed on 2026-07-15 after the issue set above was frozen.

### Delivered changes

- Added persistent charger-management-service CRUD for network operators, station makes, port levels, station models, site controllers, and charger groups.
- Added update contracts for chargers, EVSEs, and connectors and retained stable record identifiers during edits.
- Replaced search-only View actions with read-only detail screens and explicit Back/Edit actions.
- Added 25-row paging to location, charger, EVSE, and connector inventory screens. Production now reports `Showing 1-25 of 1053` connectors.
- Removed the misleading regular-user Edit action; the remaining View action is intentionally read-only.
- Passed the selected dashboard period, filters, revenue, session count, energy, unique users, and average session value to Sparky.
- Added mobile record cards for persistent reference data and connectors, constrained the charging-session layout, and corrected global phone-width overflow.

### Build and deployment evidence

- `charger-management-service` TeamCity build `#15`: success; production image `amolsurjuse/charger-management-service:15`.
- `ai-support-service` TeamCity build `#3`: success; production image `amolsurjuse/ai-support-service:3`.
- `admin-portal-ui` TeamCity build `#42`: success; production image `amolsurjuse/admin-portal-ui:42`.
- Production Argo applications for all three services were synced and reached `Healthy`.

### Production Chrome evidence

- Re-ran all 23 routes as `SYSTEM_ADMIN`; every route loaded without an application alert.
- Exercised list, detail, add, and edit states for hierarchy, reference-data, charger, EVSE, connector, pricing, subscription, user, RBAC, receipt, notification, and charger-configuration surfaces without submitting destructive mutations.
- Confirmed charger, EVSE, and connector Edit states are prefilled and submit as `Update`, not `Create`.
- Confirmed an unread notification changes from unread to read when opened (`7` to `6`).
- Confirmed a completed session receipt displays charging cost, idle fee, taxes, subscription discount, total, payment method, and status.
- At a 390 px Chrome viewport, the audited pages have no document-level horizontal overflow. Connector and reference-data mobile cards are visible and inventory detail/edit screens remain within the viewport.
- Confirmed Sparky returned the exact live dashboard value: `USD 72,128.91` for 1,721 completed sessions in the selected period.
- Desktop and mobile Chrome console diagnostics contained no errors or warnings.
