# Request Documentation

Every material user request should have its own folder under `docs/requests/`.

## Folder naming

Use this format:

```text
YYYY-MM-DD-short-request-slug
```

Example:

```text
2026-07-07-performance-latency-audit
```

## Required document

Each request folder should contain at least one Markdown document that records:

- Original request summary
- Scope
- Repositories and services reviewed or changed
- Findings, decisions, and assumptions
- Implementation or execution plan
- Validation plan
- Status and next steps

This keeps chat-driven work auditable even when the implementation spans multiple ElectraHub repositories.
