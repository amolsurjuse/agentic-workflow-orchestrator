# Sparky Prompt And Context Audit

Last audited: 2026-07-10
Last validated: 2026-07-10

## Scope

This document inventories the Sparky prompts currently exposed by:

- Driver Portal iOS: `driver-portal-ios`
- Admin Portal: `admin-portal-ui`
- AI backend: `ai-support-service`

It also maps the expected context payload, backend diagnostic route, expected response shape, and current readiness status for each prompt.

## Context Contract

All Sparky clients call `POST /ai/api/v1/chat/messages` with:

| Field | Purpose | Current backend use |
| --- | --- | --- |
| `screen` | Current UI screen or page | Used for audience and route selection, especially dashboard revenue |
| `resourceType` | Type of focused entity | Used in prompt formatting and page-level grounding |
| `resourceId` | Generic focused entity id | Accepted by API but not currently used by backend diagnostics |
| `chargerId` | Selected charger | Used for charger GraphQL status, OCPP connection, and OCPP history |
| `connectorId` | Selected connector | Used for connector status and active session matching |
| `locationId` | Selected location | Included in context summary; not currently used for live diagnostics |
| `sessionId` | Selected charging session | Used for current session and meter value diagnostics |
| `audience` | `driver`, `admin`, or `support` | Controls driver-safe vs admin/support diagnostic wording |

## Backend Diagnostic Coverage

| Diagnostic source | Trigger | Current behavior |
| --- | --- | --- |
| Payment state | Bearer token present | Reads wallet balance, wallet budget, saved cards, auto top-up |
| Session state | `sessionId` or active session token context | Reads current session by id, otherwise active sessions and matching connector |
| Meter values | `sessionId` present | Reads latest stored meter value |
| Charger state | `chargerId` or `connectorId` present | Reads OCPI charger GraphQL status, ports, current session, connector state |
| OCPP connection | `chargerId` present | Reads active/local/db connection and last heartbeat |
| OCPP history | `chargerId` present | Reads recent OCPP actions and latest telemetry-like event |

## iOS Prompt Inventory

Source: `DriverPortalIOS/Models/ChatContext.swift`

| Screen | Prompt | Context sent today | Expected backend route | Expected response | Context ready? | Response ready? | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Map / charger detail | `Is this charger available?` | `screen=map`, `audience=driver`; when a charger detail is loaded: `resourceType=charger`, `resourceId=chargerId`, `chargerId`, `connectorId`, `locationId` | `check_charger_availability` | Direct yes/no based on live `availablePorts`, `busyPorts`, charger status, and connector `available` | [x] | [x] | Recently fixed so charger detail publishes selected charger context. |
| Map / charger detail | `What does this status mean?` | Same as map context above | Usually `driver_support_context` or `check_charger_liveness` if message mentions online/offline/heartbeat | Explain visible status using live charger facts; if context missing, say live status cannot be confirmed | [x] | [~] | No dedicated status-explanation route yet; LLM/fallback uses diagnostics. |
| Map / charger detail | `Find another CCS charger` | Same as map context above; no search radius/user location passed | `driver_support_context` | Should explain current backend cannot perform charger search and suggest using map filter/search | [~] | [~] | Backend has no charger search tool; user location/filter context is not sent. |
| Live Charging | `Why is charging stuck?` | `screen=liveCharging`, `resourceType=charging`, `audience=driver`; currently no active `sessionId`/charger context from `MainTabView` | `diagnose_session_state` when message contains `stuck` or `preparing` | Explain Preparing/stuck state and include live session/meter facts if session context exists | [ ] | [~] | Needs active session context from `LiveChargingView` into `MainTabView`. |
| Live Charging | `Why did start fail?` | `screen=liveCharging`, `resourceType=charging`, no selected session | `diagnose_charging_start` when message mentions `503`, `unavailable`, or related terms; otherwise generic | Explain OCPP routing, charger connection, connector availability, existing session, and payment checks | [ ] | [~] | Prompt wording may not hit the 503/unavailable route; backend should add explicit start-failure detection. |
| Live Charging | `Is my charger online?` | `screen=liveCharging`, `resourceType=charging`, no selected charger | `check_charger_liveness` | Explain heartbeat/OCPP connection state if `chargerId` is present; otherwise state missing charger context | [ ] | [x] | Needs live charging charger context. |
| Dashboard | `Why did my last charge fail?` | `screen=dashboard`, `audience=driver`, no session id | `driver_support_context` or charging-start fallback depending wording | Explain likely failure checks; should ideally inspect latest failed session | [ ] | [~] | Backend has no latest-session lookup by failure/completed history. |
| Dashboard | `How much did I spend last month?` | `screen=dashboard`, no date/account context beyond bearer token | `driver_support_context` | Should state current backend lacks monthly spend aggregation unless a dashboard endpoint is added | [ ] | [ ] | No spend analytics diagnostic tool. |
| Dashboard | `My most used station` | `screen=dashboard`, no date/account context beyond bearer token | `driver_support_context` | Should state current backend lacks usage aggregation unless history analytics are added | [ ] | [ ] | No station usage aggregation diagnostic tool. |
| Payments | `Why was I charged $X?` | `screen=payments`, `audience=driver`, bearer token | `driver_support_context` plus payment state diagnostics | Explain wallet/cards and advise opening receipt; should use session/receipt if provided | [~] | [~] | No selected receipt/session context from Payments screen. |
| Payments | `Compare pricing plans` | `screen=payments`, no tariff/location context | `driver_support_context` | Should compare only if pricing plan data is available; otherwise guide user to pricing screen | [ ] | [ ] | Backend has no pricing-plan lookup. |
| Payments | `How does idle fee work?` | `screen=payments`, no tariff/location context | `driver_support_context` / knowledge base pricing and idle fee | Explain grace period, per-minute fee, receipt separation, and caps if configured | [~] | [~] | Knowledge exists, but no tariff-specific lookup unless charger context is sent. |
| History | `Show last receipt` | `screen=history`, no selected session/receipt id | `driver_support_context` | Should say receipt requires selecting a session unless history API is added | [ ] | [ ] | Backend has no last receipt lookup. |
| History | `Total kWh this year` | `screen=history`, no date/account context | `driver_support_context` | Should say annual aggregation is unavailable unless history analytics are added | [ ] | [ ] | Backend has no yearly kWh aggregation. |
| History | `Trips over 100 km` | `screen=history`, no trip data context | `driver_support_context` | Should say Sparky does not have trip distance data | [ ] | [ ] | EV trip data is outside current backend diagnostics. |

## Admin Portal Prompt Inventory

Source: `admin-portal-ui/src/components/SparkyAssistant.tsx`

Admin Portal currently has one global quick-prompt set on every page. It sends:

- `audience=admin`
- `screen=activePage`
- `resourceType=pageResourceHints[activePage] ?? admin`

It does not send selected row IDs (`sessionId`, `chargerId`, `connectorId`, `locationId`) from table/detail views today.

| Prompt | Context sent today | Expected backend route | Expected response | Context ready? | Response ready? | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `Why is a session still idle after remote stop?` | `audience=admin`, `screen=<activePage>`, `resourceType=<page resource>` | `diagnose_idle_remote_stop` | Admin/support explanation: check session-service state, remoteStopRequestedAt, status, idleStartedAt, receipt events; then ocpp-service/simulator connector Redis, StopTransaction/TransactionEvent, StatusNotification, unplug event | [~] | [x] | Works generically, but lacks selected `sessionId`, `chargerId`, and `connectorId` for live diagnosis. |
| `What should admin see for a tap credit card session?` | `audience=admin`, page-level context only | `explain_card_present_admin_payment` | Explain payment should show Credit Card, masked card when available, ElectraHub authorization id instead of raw processor transaction id, anonymous possible | [~] | [x] | Works as expected-behavior answer; selected session/payment context not sent. |
| `What should I check if the simulator unplug is not working?` | `audience=admin`, page-level context only | `diagnose_simulator_secure_unplug` | Admin explanation: app link should include security code; simulator should authorize unplug for active/idle idle-fee session; no code required when idle fee disabled/no active session | [~] | [x] | Works as expected-behavior answer; live connector/session context not sent. |

## Admin Page Context Matrix

| Admin page | `activePage` | Current `resourceType` | Current selected entity context | Recommended context enhancement |
| --- | --- | --- | --- | --- |
| Dashboard | `dashboard` | `admin` | None | Send dashboard date filter/window for revenue/cost questions |
| Users | `users` | `admin` | None | Send selected user/account id when a user row/detail is open |
| Admin Users | `admin-users` | `admin` | None | Send selected admin user id and role if detail is open |
| Subscriptions | `subscriptions` | `subscription` | None | Send selected subscription/user/account id |
| RBAC Policy | `rbac-policy` | `admin` | None | Send selected role/policy id |
| Charger Enterprise | `charger-enterprise` | `admin` | None | Send selected enterprise/operator id |
| Charger Network | `charger-network` | `admin` | None | Send selected network/operator id |
| Charger Location | `charger-location` | `admin` | None | Send selected `locationId` |
| Charger Groups | `charger-groups` | `admin` | None | Send selected group id and charger ids |
| Chargers | `chargers` | `charger` | None | Send selected `chargerId`, `locationId`, network/operator when a charger row/detail is active |
| EVSEs | `evses` | `evse` | None | Send selected EVSE id, charger id, location id |
| Connectors | `connectors` | `connector` | None | Send selected `connectorId`, `chargerId`, `locationId` |
| Allocations | `allocations` | `admin` | None | Send selected allocation id/user/subscription id |
| Utilizations | `utilizations` | `admin` | None | Send selected date/window and aggregation filters |
| Charging Sessions | `charging-sessions` | `session` | None | Send selected `sessionId`, `chargerId`, `connectorId`, `locationId`, payment/auth method |
| Notifications | `notifications` | `notification` | None | Send selected notification id/status |
| Audit Logs | `audit-logs` | `admin` | None | Send selected audit event id/entity id |
| Pricing | `pricing` | `tariff` | None | Send selected tariff/price plan id and location/charger if scoped |
| Network Operator | `network-operator` | `admin` | None | Send selected operator id |
| Charge Station Make | `charge-station-make` | `admin` | None | Send selected make id |
| Port Level | `port-level` | `admin` | None | Send selected connector/port level id |
| Charge Station Model | `charge-station-model` | `admin` | None | Send selected model id |
| Site Controller | `site-controller` | `admin` | None | Send selected controller id/site id |

## Backend Answer Route Matrix

| Route/tool | Trigger | Exact deterministic? | Expected investigation steps |
| --- | --- | --- | --- |
| `check_charger_availability` | Availability/free/busy/occupied + charger/connector/station terms | Yes | Fetch charger GraphQL status, connector availability, current session, OCPP connection/history when charger context exists |
| `diagnose_idle_remote_stop` | Remote stop/stop charging + idle fee/receipt/unplug | Yes | Check session-service idle/SUSPENDED state, unplugRequiredToStop, receipt timing, ocpp-service/simulator Redis, StopTransaction/TransactionEvent, StatusNotification, unplug |
| `diagnose_simulator_secure_unplug` | Simulator + security code/unplug/mobile app/link | Yes | Verify app URL security-code pass-through, simulator HMI handling, idle-fee session authorization, no-code unplug for no active session/idle fee disabled |
| `explain_card_present_admin_payment` | Tap credit/card present/credit card + payment/admin/receipt/transaction/session | Yes | Explain expected admin/receipt fields; should avoid raw processor transaction id and full card data |
| `explain_admin_total_revenue` | Revenue/sales/income, short dashboard query or dashboard/admin context | Yes | Explain completed-session revenue, date filter, previous equivalent window, receipt alignment |
| `diagnose_charging_start` | 503/unavailable/temporarily | No | Check charger connection, connector availability, active/preparing/finishing session, OCPP command routing, payment eligibility |
| `diagnose_active_connector` | already_active/already active/in progress | No | Check existing session for connector and whether it belongs to driver |
| `diagnose_session_state` | stuck/preparing | No | Check session state, meter movement, charger offline/busy/no meter updates |
| `check_charger_liveness` | online/offline/heartbeat | No | Check OCPP heartbeat and connection status |
| `driver_support_context` | Fallback | No | General support answer enriched with available backend facts |

## Prompt Quality Checklist

| Area | Check | Status | Evidence / gap |
| --- | --- | --- | --- |
| iOS map charger context | Selected charger detail sends charger/connector/location | [x] | `StationMapView.publishChatContext()` updates `MainTabView.mapChatContext` |
| iOS live charging context | Active session sends session/charger/connector/location | [ ] | `MainTabView` currently sends `.liveCharging()` with no active values |
| iOS dashboard/payments/history context | Selected receipt/session/payment context sent when relevant | [ ] | Current tab-level context only |
| iOS user feedback while waiting | Chat shows active thinking/writing state | [x] | `ChatBubbleRow` shows `Sparky is checking live charger status...` while streaming |
| Admin global context | Active page and broad resource type sent | [x] | `SparkyAssistant` sends `screen=activePage`, `resourceType=pageResourceHints[...]` |
| Admin selected row context | Selected session/charger/connector sent | [ ] | No row/detail IDs are passed into `SparkyAssistant` today |
| Admin waiting indicator | Chat shows working state while loading | [x] | Admin UI shows `Checking ElectraHub context...` |
| Backend availability correctness | Availability answer cannot contradict live facts | [x] | `check_charger_availability` exact deterministic route |
| Backend exact project flows | Known sensitive flows bypass LLM contradiction | [x] | Exact routes for idle stop, simulator unplug, card-present, revenue, availability |
| Backend analytics questions | Spend/kWh/most-used station answers backed by APIs | [ ] | No aggregation/history diagnostic source yet |
| Backend pricing questions | Price plan/tariff comparison backed by APIs | [ ] | No pricing-service diagnostic source yet |

## 2026-07-10 Validation Update

After the initial audit, live validation found that Ollama was over-generalizing weak fallback answers for:

- `Why did start fail?`
- `How much did I spend last month?`
- `Show last receipt`
- `Why is a session still idle after remote stop?`

Fixes applied:

- Added exact deterministic backend routes for start failure, stuck/preparing state, receipt lookup without selected session, missing spend analytics, missing usage analytics, missing trip telemetry, missing pricing context, and charger search gaps.
- Expanded `DiagnosticAnswerServiceTest` with prompt-regression tests for the documented weak prompts.
- Updated the Ollama `electrahub-sparky` Modelfile and runtime prompt rules so the model must preserve authoritative fallback limitations and must not invent spend, kWh, station, trip, receipt, pricing, card, wallet, charger, or session values.
- Rebuilt the local Ollama `electrahub-sparky` model from the updated Modelfile.
- Deployed `ai-support-service` image `20260710-sparky-prompt-audit-r2`.

Live production spot checks passed for:

| Prompt | Expected route | Live result |
| --- | --- | --- |
| `Show last receipt` | `explain_receipt_lookup` | Asks user to open/select a specific history receipt; no unrelated wallet facts |
| `How much did I spend last month?` | `explain_spend_analytics_gap` | States monthly spend needs dated receipt/session aggregation API |
| `Why did start fail?` | `diagnose_charging_start` | Explains likely start-failure causes and states exact live diagnosis needs selected charger/connector/session |
| `Why is a session still idle after remote stop?` | `diagnose_idle_remote_stop` | Gives admin diagnostic steps for session-service, ocpp-service, simulator Redis/status/unplug/receipt flow |

## Recommended Follow-Up Implementation Plan

1. Add a shared `SparkyContextProvider` contract per client so screens can publish selected entity context, not only active page/tab.
2. iOS: wire `LiveChargingView` to publish active `sessionId`, `chargerId`, `connectorId`, and `locationId` to `MainTabView`.
3. iOS: wire selected receipt/history/payment context when opening receipt, history detail, or payment charge detail.
4. Admin Portal: add selected entity state to `App` or a context store and pass it to `SparkyAssistant`.
5. Admin Portal: update Charging Sessions, Chargers, EVSEs, Connectors, Pricing, Notifications, and Audit pages to publish selected row/detail ids.
6. Backend: add diagnostic clients for pricing plans, session receipt/history, admin session search, dashboard metrics, and usage aggregations.
7. Backend: add exact deterministic routes for `How much did I spend last month?`, `Show last receipt`, `Total kWh this year`, and `Compare pricing plans` once supporting APIs exist.
8. Add regression tests that post each prompt with representative context and assert the selected route, context summary, and key response text.
