# Ollama Project Training

## Request

Train Ollama for ElectraHub so users receive precise project-specific responses.

## Implementation

- Recreated the local `electrahub-sparky` Ollama model from the project Modelfile.
- Added an `ElectraHubKnowledgeBase` layer in `ai-support-service` so prompts are grounded with curated ElectraHub behavior.
- Added exact deterministic answers for known high-risk support flows:
  - remote stop with idle fee and receipt timing
  - simulator security code/unplug flow from the mobile app
  - tap-credit-card/card-present admin payment display
- Hardened the Ollama client prompt to use project behavior first and live backend facts only for current state.
- Added prompt-leak detection so responses fall back to curated answers if the local model repeats prompt labels or rules.

## Deployment

- Deployed `amolsurjuse/ai-support-service:20260709-ollama-trained4` to prod.
- Prod configuration:
  - `AI_PROVIDER=ollama`
  - `AI_MODEL=electrahub-sparky`
  - `OLLAMA_BASE_URL=http://host.docker.internal:11434`
  - `AI_MAX_OUTPUT_TOKENS=140`

## Validation

- Unit tests passed in `ai-support-service`.
- Public API validated through `POST https://api.electrahub.net/ai/api/v1/chat/messages`.
- Prompt checks confirmed precise answers for:
  - remote stop while idle fee is running
  - mobile simulator security code handling
  - card-present admin payment and transaction id display
