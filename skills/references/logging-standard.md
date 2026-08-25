# Skill: OpenTelemetry Logging Standardization

> **Agent instruction:** Read this file top to bottom. Execute every step in order.
> Do NOT ask the user any questions. Make decisions using the rules in each step.
> If a file already satisfies a rule, skip that rule silently and continue.

---

## Context

This skill standardizes error logging and OpenTelemetry trace/span ID correlation across all
Java Spring Boot services in this organization. Apply it to one service repo at a time.
Build tool is Maven. Logging framework is Logback (via `spring-boot-starter`).

This skill enforces the **ElectraHub Logging Standard**. Every change must produce logs that match
the canonical pattern defined below.

---

## Canonical Log Pattern (ElectraHub Standard)

Every log line — in all environments — must contain these fields in this order:

```
%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} %-5level %property{PID} --- [%property{APP_NAME}] [%thread] traceId=%X{traceId:-} spanId=%X{spanId:-} %logger{36} : %msg%n%ex
```

| Field | Description |
|-------|-------------|
| `%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX}` | ISO-8601 timestamp with timezone offset |
| `%-5level` | Log level, left-padded to 5 chars |
| `%property{PID}` | OS process ID |
| `[%property{APP_NAME}]` | Service name from `spring.application.name` |
| `[%thread]` | Thread name |
| `traceId=%X{traceId:-}` | OTel trace ID from MDC (empty placeholder when no span active) |
| `spanId=%X{spanId:-}` | OTel span ID from MDC (empty placeholder when no span active) |
| `%logger{36}` | Logger class name, max 36 chars |
| `%msg` | Log message |
| `%n%ex` | Newline + full exception stack trace when present |

---

## Step 1 — Read the project first

1. Read `pom.xml` to determine the Spring Boot version and which dependencies are already present.
2. List `src/main/resources/` and `src/test/resources/` to see what config files exist.
3. Search every `.java` file under `src/main/java/` for: `log`, `logger`, `error`, `exception`, `catch`, `failure`.
4. Search for any existing MDC usage: `MDC.put`, `MDC.remove`, `MDC.clear`.
5. Search for async boundaries: `@Async`, `@Scheduled`, `ExecutorService`, `@KafkaListener`, `@RabbitListener`, `RedisTemplate`.
6. Record all findings internally. Do not print yet.

---

## Step 2 — Add Maven dependencies

Edit `pom.xml`. Apply **only the blocks that are missing**:

### 2a — Micrometer OpenTelemetry bridge (required for traceId/spanId MDC population)

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
```

> Decision rule: search `pom.xml` for `micrometer-tracing-bridge-otel`. If found, skip 2a.

### 2b — OpenTelemetry OTLP exporter (required to send traces to collector)

```xml
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
```

> Decision rule: search `pom.xml` for `opentelemetry-exporter-otlp`. If found, skip 2b.

### 2c — Janino (required for conditional `<if>` blocks in logback-spring.xml)

```xml
<!-- Janino — required for conditional blocks in logback-spring.xml -->
<dependency>
    <groupId>org.codehaus.janino</groupId>
    <artifactId>janino</artifactId>
</dependency>
```

> Decision rule: run `mvn dependency:tree | grep janino`. If output is non-empty, skip 2c.

Add all three dependencies in the `<dependencies>` section, after any existing micrometer entries.

---

## Step 3 — Create `src/main/resources/logback-spring.xml`

> Decision rule: if `src/main/resources/logback-spring.xml` already exists AND its LOG_PATTERN
> contains `%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX}` AND `%property{PID}` AND `%X{traceId` AND `%X{spanId`
> AND `%ex`, skip this step. Otherwise overwrite it entirely.

Create (or overwrite) the file with exactly this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProperty scope="context" name="APP_NAME" source="spring.application.name" defaultValue="api-gateway"/>
    <springProperty scope="context" name="PID" source="spring.application.pid" defaultValue="???"/>

    <!-- LOG_FILE_ENABLED defaults to false — containers/pods log to stdout only.
         Set LOG_FILE_ENABLED=true ONLY for bare-metal / VM deployments with a writable log directory.
         Never set this to true in Kubernetes pod specs — the log directory will not exist. -->
    <property name="LOG_FILE_ENABLED" value="${LOG_FILE_ENABLED:-false}"/>
    <property name="LOG_DIR" value="${LOG_DIR:-logs}"/>

    <!-- ElectraHub canonical log pattern — do NOT change field order or names -->
    <property name="LOG_PATTERN"
              value="%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} %-5level ${PID} --- [${APP_NAME}] [%thread] traceId=%X{traceId:-} spanId=%X{spanId:-} %logger{36} : %msg%n%ex"/>

    <!-- Console appender — always active (stdout for Kubernetes log collection) -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
        </encoder>
    </appender>

    <root level="${LOGGING_LEVEL_ROOT:-INFO}">
        <appender-ref ref="CONSOLE"/>
    </root>

    <!-- Rolling file appender — entire block inside <if> so Logback never parses or starts it
         unless LOG_FILE_ENABLED=true. This prevents FileNotFoundException in containers. -->
    <if condition='property("LOG_FILE_ENABLED").equals("true")'>
        <then>
            <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
                <file>${LOG_DIR}/${APP_NAME}.log</file>
                <encoder>
                    <pattern>${LOG_PATTERN}</pattern>
                </encoder>
                <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
                    <fileNamePattern>${LOG_DIR}/${APP_NAME}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
                    <maxFileSize>10MB</maxFileSize>
                    <maxHistory>14</maxHistory>
                    <totalSizeCap>1GB</totalSizeCap>
                </rollingPolicy>
            </appender>
            <root level="${LOGGING_LEVEL_ROOT:-INFO}">
                <appender-ref ref="FILE"/>
            </root>
        </then>
    </if>
</configuration>
```

---

## Step 4 — Create `src/test/resources/logback-test.xml`

> Decision rule: if `src/test/resources/logback-test.xml` already exists AND its pattern
> contains `%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX}` AND `%X{traceId` AND `%X{spanId`, skip.
> Otherwise overwrite it entirely.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- Mirrors the ElectraHub canonical pattern for consistent test output -->
    <property name="LOG_PATTERN"
              value="%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} %-5level [%thread] traceId=%X{traceId:-} spanId=%X{spanId:-} %logger{36} : %msg%n%ex"/>

    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
    </root>
</configuration>
```

---

## Step 5 — Update `application.yaml` (or `application.properties`)

### 5a — Remove inline log pattern if present

> Decision rule: search for `logging.pattern.console` in all yaml/properties config files.
> If found, delete that entire line. `logback-spring.xml` is the single source of truth for formatting.

### 5b — Add OTLP tracing endpoint config

> Decision rule: search for `management.otlp.tracing.endpoint`. If found, skip 5b.

Add under the `management:` block:

```yaml
  otlp:
    tracing:
      endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:http://localhost:4318/v1/traces}
```

If `management.tracing.sampling.probability` is also missing, add:

```yaml
  tracing:
    sampling:
      probability: ${OTEL_TRACING_SAMPLING_PROBABILITY:1.0}
```

---

## Step 6 — Fix error logging in all Java source files

Scan every `.java` file under `src/main/java/`. Apply these rules in order:

### 6a — Use the correct log level

| Situation | Level to use |
|-----------|-------------|
| Expected lifecycle: startup, request received, job started, message received | `INFO` |
| Recoverable issue: retry, fallback used, partial failure, missing optional config | `WARN` |
| Failure that needs operator attention: unhandled exception, data loss risk, security event | `ERROR` |

Do NOT change a `WARN` to `ERROR` unless the situation clearly matches the ERROR criteria above.
Do NOT change an `INFO` that represents normal lifecycle (e.g., "Starting ...", "Completed ...").

### 6b — Exception/failure catch blocks

Pattern to find: `catch` block that calls `log.info(...)` or `log.warn(...)` where the exception
indicates a genuine failure (not a suppressed/ignored one). Change to `log.error(...)` and pass
the exception as the **last argument**.

Before:
```java
} catch (Exception ex) {
    log.info("Failed to process: {}", ex.getMessage());
}
```

After:
```java
} catch (Exception ex) {
    log.error("Failed to process: {}", ex.getMessage(), ex);
}
```

### 6c — Failure-handling methods

Locate methods named `logFailure`, `logError`, `onError`, `handleException`, `onFailure`, etc.
If the log call inside is not at `ERROR` level, change it.
If the exception object is available but not the last argument, add it.

### 6d — Structured log message phrases

When writing NEW log statements or when an existing message is being changed for another reason,
use these standard phrases to keep logs searchable across services:

- Starting operations: `"Starting <action>"` or `"Starting <entity>.<method>"`
- Completed operations: `"Completed <action> in {} ms"`
- Failure operations: `"Failed <action>: {}"`

Do NOT rename existing messages that you are not otherwise changing.

### 6e — Do NOT touch

- `catch (Exception ignored)` or `catch (Exception e) { /* intentionally suppressed */ }` blocks.
- Any log call that already uses `ERROR` level with the exception as the last argument.
- Any existing masking, redaction, or sanitization logic — leave it entirely intact.

---

## Step 7 — Sensitive data rules (audit existing logging)

Scan all `.java` logging calls for violations of these rules. Fix any found:

- **Never log**: access tokens, refresh tokens, JWT payloads, API keys, passwords, secrets,
  payment card numbers, CVVs, IBAN values, raw HTTP `Authorization` headers, OCPI/OCPP credentials.
- **Redact identifiers** that are not needed for troubleshooting (e.g., full email, phone number).
- If a body/payload is logged for debugging, only the minimal fields needed to describe
  the failure should be included; not the full payload.

> Decision rule: if the class already has masking/redaction logic that covers the above fields,
> do not change it. Only add redaction where a value is clearly logged in the clear.

---

## Step 8 — MDC preservation for async boundaries

Search for the async patterns found in Step 1 (`@Async`, `@Scheduled`, `@KafkaListener`,
`@RabbitListener`, scheduled tasks, `ExecutorService`).

For each async boundary found:

1. Confirm that MDC context (`traceId`, `spanId`) is either:
    - Automatically propagated by the tracing library (e.g., Micrometer tracing configured to wrap executors), OR
    - Manually copied with `MDC.getCopyOfContextMap()` before submission and restored with
      `MDC.setContextMap(...)` inside the task.
2. If MDC is not propagated and there is no manual copy, log a `WARN` comment in the code:
   ```java
   // TODO: MDC/trace context not propagated across this async boundary — see ElectraHub Logging Standard
   ```
   Do not make speculative code changes to threading logic; only flag it.

---

## Step 9 — Final YAML cleanup

Scan all `application*.yaml` and `application*.properties` files for any remaining
`logging.pattern.console` or `logging.pattern.file` entries and remove them.

---

## Step 10 — Verify

1. Run: `mvn -Dtest=<ContextTestClass> test`
    - Substitute with any class annotated `@SpringBootTest` found in `src/test/`.
    - If none found, run: `mvn test`
2. Run any test class that covers a changed logging component.
3. Both must produce `BUILD SUCCESS`.
4. If a test fails because of a changed log level, update the assertion to match the new level.
5. Visually confirm that the console test output lines contain:
    - ISO-8601 timestamp (e.g., `2026-06-16T16:28:36.741+00:00`)
    - `traceId=` and `spanId=` fields
    - Service name in brackets (e.g., `[api-gateway]`)

---

## Step 11 — Output a change summary

```
### OTel Logging Standardization — Change Summary

**Dependencies added:**
- list each, or "none (already present)"

**Files created:**
- list each

**Files modified:**
- list each with a one-line reason

**Error logging fixes:**
- list each method/class fixed: original level → new level

**Sensitive data issues found:**
- list any, or "none found"

**Async MDC gaps flagged:**
- list any TODO comments added, or "none found"

**Tests run:**
- command used
- result (PASS / FAIL)

**How to enable OTLP export:**
  export OTEL_EXPORTER_OTLP_ENDPOINT=http://<your-collector>:4318/v1/traces
  export OTEL_SERVICE_NAME=<spring.application.name value>
  export OTEL_TRACING_SAMPLING_PROBABILITY=1.0
```

---

## Quick Usage (for humans)

Paste the **entire contents** of this file as the prompt into any agent session opened inside a
Java Spring Boot service repo. The agent will apply all changes autonomously without asking any questions.
