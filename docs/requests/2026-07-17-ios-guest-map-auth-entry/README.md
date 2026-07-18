# iOS Guest Map Authentication Entry

## Request

Keep the station map as the default iOS screen for unauthenticated visitors, but restore a clear way to sign in or create an account. Remove the redundant one-item Map tab while the visitor is browsing as a guest.

## Problem Found

`MainTabView` already allows unauthenticated map browsing, but its only map-level sign-in control is a toolbar item applied outside `StationMapView`'s internal `NavigationStack`. This makes the action unreliable or invisible in the rendered guest experience. The remaining one-item tab bar provides no useful navigation and consumes space that should be used for account entry.

## Design

1. The map remains available without an account.
2. Guests receive a persistent bottom access prompt with two explicit actions: `Sign In` and `Create Account`.
3. The prompt opens the existing authentication flow on the matching screen, avoiding a duplicate auth implementation.
4. The one-item Map tab bar is hidden only for guests. Authenticated drivers retain the existing full bottom navigation, including their current map return path.
5. Existing guest restrictions remain unchanged: visitors can search, inspect stations, pricing, and directions, but cannot start a session, manage payments, use favorites/recent stations, receive private data, or open the authenticated assistant.

## Verification

- Fresh launch with no token opens the map and shows both entry actions.
- `Sign In` opens the sign-in form.
- `Create Account` opens the registration form.
- Guest map search, station detail, pricing, and directions still work.
- Guest connector detail continues to block charging and points to authentication.
- Successful login dismisses auth and restores normal signed-in navigation.
- Logout returns to the guest map and restores the access prompt.
