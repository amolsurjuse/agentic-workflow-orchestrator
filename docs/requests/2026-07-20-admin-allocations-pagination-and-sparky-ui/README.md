# Admin Allocations Pagination And Sparky UI

## Request

- Make pagination on the Admin Portal allocations screen consistent.
- Improve the Admin Portal Sparky experience so it feels like a first-class operational tool.

## Investigation

The allocation screen used `GET /api/v1/subscriptions/allocations`, then filtered and paged the returned list in the browser. The subscription service already exposes `GET /api/v1/subscriptions/allocations/paged`, including server-side filtering and pagination metadata. This produced inconsistent totals, ignored the source and quota filters in the displayed result set, and rendered an unbounded list of page buttons.

## Implementation

### Allocations

- Use `listSubscriptionAllocationsPage` with `limit`, `offset`, allocation type, status, plan, source, exhausted, and active filters.
- Fetch the plan selector independently of allocation pages, so page navigation does not repeat that request.
- Render server-provided totals and first/previous/next/last controls through the shared pagination component.
- Clamp the current page after a mutation removes the final item on that page, then refetch the final valid page.

### Sparky

- Present the active Admin Portal workspace as live context.
- Provide screen-specific suggested prompts for dashboards, chargers, sessions, allocations, utilization, notifications, and pricing.
- Add a visible response-preparation state, conversation reset, automatic focus, and automatic message scrolling.
- Use an operational panel layout that matches the surrounding portal rather than a generic chat card.

### Sparky Follow-up UX Refinement

The first panel iteration made the context and prompt content available, but its horizontal prompt chips and weak surface boundaries made the assistant read like an unstructured form. The follow-up design makes the interaction model explicit:

- The panel is a single, strongly bordered assistant workspace with a clear AI identity and live-context status.
- Suggested prompts are full-width, vertically stacked action cards. Each card has a distinct border, a Sparky mark, readable wrapping, and a directional affordance.
- The conversation has its own labelled surface, with visually distinct assistant and operator message bubbles.
- The compose control is a framed question field with an explicit label and icon-only send action.
- Desktop and mobile layouts preserve the same vertical prompt hierarchy; no horizontal prompt scrolling is used.

## Validation

- `npm.cmd run build` completed successfully in `admin-portal-ui`.
- The Sparky refinement also passed `npm.cmd run build` after the responsive layout update.
- The local Admin Portal was started on `http://127.0.0.1:5177` for UI verification.
- The unrelated local `subscription-service` Maven suite remains blocked by pre-existing malformed Java source files across DTO and repository classes. No subscription-service change is required for this release because the paged API is already available.

## Delivery

- Commit and push the Admin Portal change on `develop`.
- Trigger and verify the Admin Portal TeamCity build, then verify Argo CD deployment to `https://admin-portal.electrahub.net/`.
