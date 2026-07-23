# Sparky Provider Routing Upgrade

## Request

Improve Sparky response quality and resilience without repeating the production overload caused by running an 8B Ollama model on CPU-only infrastructure.

## Decision

Sparky keeps deterministic, live-service diagnostics as its factual source. Language models only turn grounded facts into a concise response. The runtime uses a local-first provider chain:

| Order | Provider | Model/runtime | Enablement | Purpose |
| --- | --- | --- | --- | --- |
| 1 | vLLM | Qwen3 8B, OpenAI-compatible endpoint | GPU node only | Higher-quality local responses with continuous batching and predictable concurrency. |
| 2 | Ollama | `electrahub-sparky:4b` / Qwen3 4B instruct | Enabled in current prod | Reliable local fallback on the existing CPU-only cluster. |
| 3 | Gemini | Gemini Flash-Lite | Explicit opt-in and backend secret | Optional hosted fallback after stricter redaction. |

The current production cluster has no allocatable NVIDIA GPU. vLLM therefore remains deployed as a disabled GitOps application (`replicaCount: 0`) and the active route is `ollama`. This is intentional: enabling Qwen3 8B on CPU would increase latency and recreate the earlier 502 risk.

## Implementation

### AI support service

- Added a configured provider chain via `AI_PROVIDER_CHAIN`.
- Added a vLLM OpenAI-compatible client for `POST /v1/chat/completions`.
- Added an opt-in Gemini client for `generateContent`.
- Added local-first routing even if a hosted provider is placed first in configuration.
- Added a per-provider cooldown circuit breaker after request failures.
- Limited concurrent Ollama requests with a semaphore rather than allowing unbounded waiting.
- Reduced the grounded prompt and default response budget to 180 tokens to avoid CPU-bound verbose answers.
- Kept the deterministic answer when no provider returns a safe, useful result.
- Added stricter hosted-provider redaction for UUIDs, emails, bearer/JWT tokens, payment-card-like values, phone numbers, and obvious secret assignments.

### Kubernetes / GitOps

- Added AI provider settings to `ai-support-service` Helm values.
- Added optional `GEMINI_API_KEY` secret injection; the secret is not committed.
- Added a vLLM Helm chart and Argo CD applications for dev and prod.
- vLLM requests one NVIDIA GPU, and does not create a workload until a GPU environment explicitly sets `replicaCount: 1`.

### Evaluation

The existing 41-case Sparky regression suite now supports:

```powershell
# Current local model
powershell -ExecutionPolicy Bypass -File .\scripts\ollama\evaluate-sparky-prompts.ps1 -FailOnQualityIssue

# Future GPU vLLM endpoint
powershell -ExecutionPolicy Bypass -File .\scripts\ollama\evaluate-sparky-prompts.ps1 -Provider Vllm -BaseUrl http://localhost:8000 -FailOnQualityIssue

# Explicitly approved Gemini fallback
powershell -ExecutionPolicy Bypass -File .\scripts\ollama\evaluate-sparky-prompts.ps1 -Provider Gemini -BaseUrl https://generativelanguage.googleapis.com -ApiKey $env:GEMINI_API_KEY -FailOnQualityIssue
```

The suite covers driver and admin prompts for charger availability, charging-state diagnostics, alternatives, pricing, receipts, subscriptions, idle/unplug, card-present payment, RFID/Plug and Charge, notifications, RBAC, and operational dashboards.

## Production configuration

Current safe production posture:

```text
AI_PROVIDER_CHAIN=vllm,ollama,gemini
AI_VLLM_ENABLED=false
AI_OLLAMA_ENABLED=true
OLLAMA_MODEL=electrahub-sparky:4b
AI_OLLAMA_TIMEOUT_MS=14000
AI_OLLAMA_MAX_CONCURRENT_REQUESTS=1
AI_GEMINI_ENABLED=false
AI_HOSTED_FALLBACK_ENABLED=false
AI_PROVIDER_FAILURE_COOLDOWN_MS=30000
```

When a GPU node is available, enable vLLM first, run the 41-case suite against it, and then set `AI_VLLM_ENABLED=true`. Gemini remains disabled unless a privacy review approves it and a `GEMINI_API_KEY` is installed in the existing Kubernetes secret.

## Rollback

To immediately disable a provider, set its enable flag to `false`. No client-side change is required. The deterministic diagnostic fallback continues to answer safely if all providers are disabled or unavailable.

## Validation status

- Unit tests: 47 passing, including provider request shape, Gemini redaction, vLLM-to-Ollama fallback, circuit-breaker behavior, and existing Sparky guard coverage.
- Helm templates: rendered and linted for the AI service and zero-replica vLLM configuration.
- Real 4B prompt evaluation: 41/41 passed at 180 output tokens. Average latency was 7.25 seconds, P95 10.93 seconds, and maximum 12.19 seconds on CPU. The production local timeout is 14 seconds; GPU vLLM is the route for lower latency.
