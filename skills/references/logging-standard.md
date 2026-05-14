# ElectraHub Logging Standard

Use this reference when adding or updating logging in ElectraHub services.

## Goals

- Keep logs readable in containers and Kubernetes.
- Include trace correlation on every application log line.
- Make startup, request, job, and message-processing logs consistent across services.
- Avoid leaking secrets, tokens, payment data, OCPI credentials, PII, or raw payloads.

## Canonical Console Pattern

For Spring Boot services, prefer a `logback-spring.xml` console pattern like:

```xml
%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} %-5level %property{PID} --- [%property{APP_NAME}] [%thread] traceId=%X{traceId:-} spanId=%X{spanId:-} %logger{36} : %msg%n%ex
```

### Required fields

- timestamp in ISO-8601 format
- log level
- process id when available
- service name or application name
- thread name
- `traceId`
- `spanId`
- logger name
- message
- exception stack trace when present

## Correlation Rules

- Use MDC keys `traceId` and `spanId` consistently across services.
- Populate trace context from the active tracing system when a request, listener, or job starts.
- Preserve MDC across async boundaries, executors, schedulers, and message handlers.
- When a background task creates a new span, log the new span id and keep the parent trace id visible if available.
- If no trace exists, log empty placeholders rather than invented IDs.

## Service Logging Rules

- Log one clear start event and one completion or failure event for important operations.
- Include the domain object or action, not raw framework internals.
- Prefer structured, stable phrases such as `Starting ...`, `Completed ... in ... ms`, and `Failed ...`.
- Log at `INFO` for expected lifecycle events, `WARN` for recoverable issues, and `ERROR` only for failures that need operator attention.
- Keep stack traces for errors, but avoid dumping large request or response bodies.

## Sensitive Data Rules

- Never log access tokens, refresh tokens, API keys, secrets, passwords, payment credentials, or raw authorization headers.
- Never log full OCPI/OCPP payloads if they may contain personal or credential data.
- Redact identifiers when they are not required for troubleshooting.
- If a payload must be inspected, log only the minimal fields needed to understand the failure.

## Spring Boot Service Checklist

When updating a service, verify all of the following:

1. `logback-spring.xml` prints `traceId` and `spanId`.
2. The service name is visible in the log pattern.
3. MDC is restored in message listeners, scheduled jobs, and async execution paths.
4. Trace propagation works for Redis, messaging, HTTP clients, and background work.
5. Exception logs use a standard pattern and do not fail Logback startup.
6. Startup logs remain clean in Kubernetes/container output.

## Recommended Validation

- Start the service locally or in a container and confirm `traceId=` / `spanId=` appear in request and message-handler logs.
- Run unit tests that assert MDC/trace metadata is preserved across publication or listener boundaries.
- Verify Logback initializes without unsupported conversion words.
- Check that no sensitive values appear in sample logs.

## Copy-Forward Guidance

If a service already has a custom logging pattern, migrate it toward this standard rather than inventing a new one.

If you need a service-specific override, keep the same field order and naming so operators can search logs consistently across all ElectraHub services.
