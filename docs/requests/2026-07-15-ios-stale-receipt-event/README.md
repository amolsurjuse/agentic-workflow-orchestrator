# iOS Stale Receipt Event Isolation

## Request

Prevent a newly started iOS charging session from showing the charging-complete or receipt-preparing screen while the backend session remains active.

## Production Evidence

- Active session: `c6ad8123-2246-40df-92c6-369d7018b92c`
- Charger: `EH-US-CHG-0401`
- Connector: `CON-US-0401`
- New session started at `2026-07-15T19:22:55Z` and continued receiving meter values.
- Previous session `26095297-693f-4ff4-a628-7b1681e74fa1` completed and produced its receipt at approximately `2026-07-15T19:22:40Z`.
- The session service retains the most recent receipt stream event for 120 seconds per driver account.
- The iOS screenshot showed the receipt-preparing overlay while the new session remained active in the database and stream.

## Root Cause

1. Receipt replay was cached by account rather than by the session currently displayed by a client.
2. The new session began within the prior receipt's 120-second replay window.
3. iOS accepted `terminal`, `receipt-preparing`, and `receipt-ready` events without requiring their session ID to match the visible active session.
4. A receipt-ready event without a decodable ID fell back to the current active session ID, allowing an old event to navigate to the new session's receipt screen.
5. Delayed receipt UI tasks were not retained or cancelled, so a timer created for one session could update a later session's UI.

## Design

### Session Service

- After a genuinely new session is durably created, clear the account's prior cached receipt replay before exposing the new active session.
- Do not clear the receipt cache for idempotent start responses or an already-active session.
- Treat cache invalidation as best effort so a Redis outage cannot reject an otherwise valid charging start.
- Preserve the existing replay capability for reconnecting clients after a real terminal event.

### iOS

- Reset all receipt navigation and completion state when loading a new session.
- Require an explicit event session ID for terminal and receipt lifecycle events.
- Ignore events whose session ID differs from the visible active session.
- Never infer a receipt event's session from the current screen.
- Retain and cancel delayed receipt transition tasks during session changes, reconnects, and view teardown.
- Re-check the active session ID when a delayed transition wakes up.

## Validation

- Session-service commit: `1c6adce`.
- Driver Portal iOS commit: `c661e95`.
- Session-service tests: `68/68` passed.
- Added coverage for receipt-cache invalidation and Redis-failure tolerance.
- `git diff --check` passed for session-service and driver-portal-ios.
- Confirmed `PREPARING` is already included in backend driver-visible active statuses.
- Confirmed production continued receiving meter values for the reported active session while iOS displayed the stale completion overlay.
- TeamCity session-service build `85` passed for commit `1c6adce`.
- Production is `Synced/Healthy` on `amolsurjuse/session-service:85` with two ready replicas and zero restarts.
- The production Redis receipt replay scan returned no stale account receipt keys.
- The reported session remained backend-active as `SUSPENDED` after deployment, confirming that the completion overlay was client state rather than a completed session.
- iOS compilation requires the macOS/Xcode CI environment and cannot run in the Windows workspace.

## Acceptance Criteria

- [x] A new session invalidates a prior account-level receipt replay.
- [x] iOS ignores terminal and receipt events for another session.
- [x] Receipt events without a session identity cannot end the visible session.
- [x] Delayed receipt tasks cannot carry over to a later session.
- [x] Backend regression tests pass.
- [ ] iOS CI build passes.
- [x] Session-service is deployed to production.
- [ ] A production start immediately after a prior receipt remains on Live Charging.
