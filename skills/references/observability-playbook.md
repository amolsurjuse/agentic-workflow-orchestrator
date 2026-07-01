# Observability Playbook

Use this when investigating Splunk/Grafana/Kubernetes logs, traces, metrics, warnings, and production incidents.

## Input Handling

Accept any of these as evidence:

- Splunk URL
- Splunk exported JSON/JSONL file
- trace id or span id
- TeamCity build URL/timestamp
- public API request/response snippet
- Kubernetes pod logs
- Grafana panel symptom

If Splunk UI cannot be accessed, request or use exported results. Do not guess from memory when logs are available.

## Splunk Search Patterns

```spl
index=* (ERROR OR WARN) earliest=-24h latest=now
```

```spl
index=* app=<service-name> (ERROR OR WARN) earliest=-4h latest=now
| stats count by level, logger, message
```

```spl
index=* traceId="<trace-id>" earliest=-2h latest=now
| sort _time
```

```spl
index=* ("HikariPool" OR "Connection is not available" OR "Could not open JPA EntityManager")
| stats count by app, message
```

## Triage Order

1. Establish exact time window and environment.
2. Group by app/service.
3. Normalize messages by replacing UUIDs, numeric ids, timestamps, and transaction ids.
4. Find the first failing service in the timeline.
5. Separate:
   - root cause
   - cascading symptoms
   - expected client/runtime noise
   - infrastructure capacity signals
6. Map root cause to repo using `electrahub-service-catalog.md`.
7. Apply smallest safe fix.
8. Verify build and, after deployment, re-query logs.

## Common ElectraHub Patterns

### Session DB saturation

Symptoms include Hikari timeout, EntityManager creation failure, session start 500/503, and downstream OCPP callback errors.

Likely fix areas:

- session-service pool/thread configuration
- slow transaction/query review
- load-test ramp and concurrency
- Postgres capacity

### OCPP stale callback flood

Symptoms include meter values for unknown transaction ids and repeated session callback 404s.

Expected if session start failed before the charger began sending meter values. Root cause is usually earlier in session-service or command routing.

### SSE timeout/disconnect

Client disconnect and long-lived request timeout should be DEBUG unless user-visible live updates fail.

### JWT lifecycle noise

Expired JWTs are normal. Preserve metrics, but do not log as ERROR unless validation is broken globally.

### Missing notification delivery

Check producer event, notification mapping, channel feature flag, registered Firebase device, provider response, and quota policy.

### Dashboard missing analytics

Check CDR event generation, billing consumer, database fact rows, Elasticsearch indexing, and dashboard API time filters.

## Output Contract

Return:

- Root cause summary
- Evidence with service, path, timestamp, and trace id when available
- Fixes applied or recommended
- Validation performed
- Remaining operational warnings
- Follow-up owner/repo
