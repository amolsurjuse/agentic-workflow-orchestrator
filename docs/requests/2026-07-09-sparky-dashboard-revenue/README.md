# Sparky Dashboard Revenue Answer Fix

## Request

Sparky returned an unrelated start-failure answer when the admin asked `Total revenue` from the admin portal dashboard.

## Issue

The AI support service routed short dashboard metric prompts through the generic diagnostic fallback. The prompt did not contain enough charger/session terms to select the dashboard revenue explanation, so Sparky answered with an unrelated operational troubleshooting response.

## Implementation

- Added a deterministic dashboard revenue route in `ai-support-service`.
- Added revenue knowledge-base coverage for dashboard, filter, and comparison questions.
- Added a regression test for the exact `Total revenue` prompt.
- Updated the production AI support image tag in `k8s-platform`.

## Validation

- Ran `mvn test` in the AI support service container.
- Built and pushed `amolsurjuse/ai-support-service:20260709-sparky-dashboard-metrics`.
- Deployed the image to the `prod` namespace.
- Validated the live chat API with:

```json
{
  "content": "Total revenue",
  "context": {
    "audience": "admin",
    "screen": "dashboard",
    "resourceType": "dashboard"
  }
}
```

The live response now explains that total revenue is completed charging revenue for the selected dashboard date filter, aligned to completed sessions and receipts, and excludes active or failed sessions.
