# iOS Charging History Actual Count

## Request

Investigate why Driver Portal iOS charging history shows exactly 50 sessions even though the driver has completed more sessions, then show the authoritative count and make all completed sessions accessible.

## Production Evidence

For driver account `eda84789-2a1c-42de-844f-72efd53cea16`, the production session database contains:

- 61 completed or billed charging sessions
- 16 invalid or failed start attempts
- 77 raw session records

The charging history count should be 61. Invalid start attempts are operational records, not completed charging history.

## Root Cause

The iOS history screen requested only the first page:

```text
GET /session/api/v1/sessions/history?page=0&size=50
```

It then rendered `sessions.count` as the total. The result was therefore capped at 50 by presentation logic, regardless of the real number of completed sessions.

The legacy backend history implementation also loaded every account session into application memory before applying page offsets. That approach made the visible limit incorrect in iOS and would become increasingly expensive as account history grew.

## Design

### Backend

New endpoint:

```text
GET /session/api/v1/sessions/history/page?page={page}&size={size}
```

Response contract:

```json
{
  "content": [],
  "totalElements": 61,
  "totalPages": 2,
  "page": 0,
  "size": 50,
  "hasNext": true
}
```

Behavior:

- Uses database-level paging and count queries.
- Returns completed and billed sessions only.
- Excludes invalid start attempts.
- Caps page size at 100.
- Keeps the legacy array endpoint unchanged for existing clients.

### iOS

- Uses `totalElements` for the Sessions summary instead of the current page length.
- Loads 50 completed sessions initially.
- Loads subsequent pages when the user reaches the bottom.
- Deduplicates session IDs while appending pages.
- Uses the dashboard aggregate for total energy and spend, so those summary values are not limited to the first page either.
- Pull-to-refresh resets pagination and reloads authoritative totals.

## Performance

The new endpoint reads only the requested page from PostgreSQL. The count is performed by the database, avoiding allocation and mapping of the driver's complete history on every request. iOS keeps a bounded initial payload and loads older history incrementally.

## Verification

- Production database count checked directly: 61 completed/billed sessions.
- Session-service test suite: 56 passed, 0 failed.
- Stable page JSON contract has a focused serialization test.
- Modified iOS files pass Swift 6 parser validation.
- Full iOS packaging requires Xcode/macOS and cannot run in the Windows workspace.

## Acceptance Criteria

- [x] Count is not derived from the first page length.
- [x] Invalid attempts do not inflate charging history.
- [x] All completed sessions can be reached through incremental paging.
- [x] Total energy and spend are not limited to loaded rows.
- [x] Existing history API consumers remain compatible.
- [x] Backend paging is database-backed and page size is bounded.
