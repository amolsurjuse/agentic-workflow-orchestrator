---
name: eh-50-android-mobile
description: ElectraHub domain subagent for Android driver-portal work (DriverPortalAndroid). Use when a story affects the Android driver app, when porting an iOS feature to Android for parity, or when the Compose UI, OkHttp/SSE plumbing, or Material 3 theming needs change. Triggered explicitly by the user (`@50-android-mobile <WORK_ID>`) or invoked by `04-delivery-architect` and `05-change-builder` when the work item touches Android.
---

# eh-50-android-mobile

Owns the `DriverPortalAndroid` codebase. See `.github/agents/eh-50-android-mobile.agent.md` for the full agent spec, scope, output format, and constraints.

## Quick reference
- Repo: `DriverPortalAndroid/` (Kotlin / Compose / Material 3 / OkHttp / kotlinx.serialization).
- Entry points: `DriverPortalApp.kt` (DI holder), `MainActivity.kt`, `ui/navigation/AppNavigation.kt`.
- Conventions: `ElectraHubColors` for accents, `GlassBackground` / `GlassComponents` for surfaces, single-Activity Compose Navigation, `Screen` sealed class for routes.
- SSE: `OkHttp EventSources` wrapped by `data/network/SSEClient.kt`. Never introduce another SSE library.
- Cert handling: dev self-signed cert is trusted by `ApiClient`/`SSEClient` only. Don't duplicate the trust manager in service classes.

## Parity rule
Default to feature parity with `driver-portal-ios`. If a change ships on one platform only, the agent output MUST list the named view/service on the other platform that needs the parity follow-up, plus a recommended ticket title.

## Validation
Follow `/docs/agent-commands.yml` for the project's Gradle build / lint / test commands. If those are missing, ask the user (per agent-rules.md Rule 2) — do not guess.
