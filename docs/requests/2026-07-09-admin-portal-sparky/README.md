# Admin Portal Sparky Integration

## Request

Add Sparky to the admin portal and deploy it.

## Implementation

- Added a floating Sparky assistant widget to the authenticated admin portal shell.
- Added admin-focused quick prompts for sessions, card-present payments, and simulator unplug troubleshooting.
- Added the current admin page as chat context with `audience=admin`.
- Added `VITE_AI_API_BASE_URL` configuration for local, example, production, and Docker builds.
- Wired the widget to `POST /ai/api/v1/chat/messages`.

## Deployment

- Built and pushed `amolsurjuse/admin-portal-ui:20260709-sparky-admin`.
- Deployed the image to the prod `admin-portal-ui` deployment.

## Validation

- `npm run build` passed.
- Public admin portal served the updated bundle containing Sparky and the AI chat endpoint.
- AI chat endpoint returned a relevant admin-support response for simulator unplug troubleshooting.
