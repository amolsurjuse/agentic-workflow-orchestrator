# Admin Charger Configuration

## Request

Add admin portal support for charger and connector management from each connector row. The admin should be able to open charger configuration, manage certificate/security-related settings, decommission chargers, trigger charger status changes, and run connector management commands.

## Implementation Scope

- Added an OCPP `ChangeAvailability` command endpoint to `ocpp-service`.
- Added charger-management admin proxy endpoints for:
  - live OCPP `GetConfiguration`
  - OCPP `ChangeConfiguration`
  - connector `ChangeAvailability`
  - connector `UnlockConnector`
  - charger `TriggerMessage`
  - charger `Reset`
  - charger decommission with inventory disable and optional OCPP inoperative command
- Added admin portal connector-row configuration action.
- Added a charger configuration dialog with:
  - connector availability override
  - connector unlock
  - trigger message
  - OCPP configuration overrides
  - certificate/security configuration keys
  - reset and decommission controls
  - last command response display

## Validation

- `npm.cmd run build` in `admin-portal-ui`
- `mvn test` in `charger-management-service` using Maven Docker image
- `mvn test` in `ocpp-service` using Maven Docker image

## Notes

Certificate management in this implementation is exposed through OCPP security/certificate configuration keys. Full OCPP certificate install/delete workflows should be added as a follow-up when charger-side certificate command support is required.
