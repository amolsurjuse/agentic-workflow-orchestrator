# Electra Hub iOS App Store Distribution Package

Prepared: 2026-07-15
App: Electra Hub for iOS and iPadOS
Primary locale: English (U.S.)

This package contains copy-ready App Store Connect metadata plus the technical and compliance checks required before submission. Text in square brackets must be replaced by an App Store account owner before review.

## 1. App Record

| Field | Recommended value | Notes |
|---|---|---|
| App name | Electra Hub | 11 of 30 characters |
| Subtitle | Find, charge, and drive | 23 of 30 characters |
| Bundle ID | `net.electrahub.driverportalios` | Matches the Xcode project |
| SKU | `EH-DRIVER-IOS-001` | Internal value; confirm it is unused |
| Version | `1.0.1` | Matches `MARKETING_VERSION` |
| Build | `3` | Matches `CURRENT_PROJECT_VERSION` |
| Primary language | English (U.S.) | Add regional localizations later |
| Primary category | Navigation | Best match for charger discovery and directions |
| Secondary category | Travel | Secondary discovery category |
| Price | Free | Payments purchase physical EV charging services, not the app |
| Copyright | `2026 [Legal entity name]` | Apple adds the copyright symbol |
| Age rating | Complete the questionnaire; lowest general-audience rating is expected | Do not mark the app as Made for Kids |
| Content rights | Confirm rights to display charger, location, tariff, and network data | Select the answer that matches network contracts |

## 2. Promotional Text

158 of 170 characters:

> Find nearby EV chargers, compare live connector pricing, start and track charging, manage payments, and keep every receipt together in one driver-focused app.

## 3. Description

Copy the following as plain text:

> Find a charger and understand the price before you plug in.
>
> Electra Hub gives EV drivers a clear view of nearby charging stations, connector availability, charging speed, and tariff details. Explore the map and get directions without creating an account. Sign in when you are ready to start and manage a charging session.
>
> EXPLORE NEARBY CHARGERS
> - Find charging stations around your current location
> - Review connector standards, availability, and maximum power
> - See energy, time, session, and idle-fee pricing before charging
> - Open turn-by-turn directions in Maps
>
> CHARGE WITH CONFIDENCE
> - Start and stop supported charging sessions
> - Follow live energy, power, elapsed time, and estimated cost
> - Receive important charging, balance, and idle-fee updates
> - View active and completed charging sessions
>
> MANAGE PAYMENTS AND SAVINGS
> - Pay with your Electra Hub wallet or a saved card
> - Configure auto top-up and monitor your balance
> - Review subscription benefits and charging savings
> - Open receipts and export them as PDF files
>
> MAKE IT YOURS
> - Save favorite chargers
> - Return to recently used charging locations
> - Manage your driver profile and account
> - Ask Sparky for screen-aware charging assistance
>
> Availability, connector status, tariffs, and charging controls depend on the participating network and station.

## 4. Keywords

87 of 100 ASCII bytes:

`electric vehicle,charger,charging station,charge point,CCS,CHAdeMO,route,wallet,receipt`

Do not add the app name or company name to the keyword field because Apple already indexes them.

## 5. URLs

| Field | Value | Status |
|---|---|---|
| Marketing URL | `https://electrahub.net/` | HTTP 200 validated on 2026-07-15 |
| Privacy Policy URL | `https://electrahub.net/privacy.html` | HTTP 200 validated on 2026-07-15 |
| Terms URL | `https://electrahub.net/terms.html` | HTTP 200 validated on 2026-07-15; not an App Store field |
| Support URL | `https://electrahub.net/#contact` | Candidate only; see release blocker below |

Apple requires the Support URL to expose usable contact information. Publish a dedicated `https://electrahub.net/support.html` page with support email, telephone number, legal entity/address where required, response expectations, and the existing inquiry form. Use that URL in App Store Connect after it is live.

## 6. What's New in Version 1.0.1

Use this for an update. Apple does not show this field for the first version:

> Explore charging before you sign in. Electra Hub now opens directly to the charger map, where anyone can find nearby stations, review connector pricing and availability, and get directions. Sign in or register only when you are ready to charge. This update also improves charger discovery, session status stability, notifications, and payment visibility.

## 7. Screenshot Storyboard

Use real app screenshots with production-like data and no debug overlays, simulator controls, secrets, or personal information.

| Order | Screen | Caption |
|---:|---|---|
| 1 | Guest map | Find nearby EV charging at a glance |
| 2 | Station details | Compare connectors, power, and availability |
| 3 | Connector pricing | Know energy, time, session, and idle fees before you charge |
| 4 | Start charging | Choose your payment method and start with confidence |
| 5 | Live charging | Track energy, power, status, and estimated cost in real time |
| 6 | Notifications | Stay informed about charging and idle-fee events |
| 7 | Payments | Manage your wallet, cards, and auto top-up |
| 8 | Receipt | Review every charge and export a detailed receipt |

Capture the required iPhone display size first, then provide iPad screenshots because the target supports iPad orientations. Keep captions short and do not include claims that cannot be reproduced in the submitted build.

## 8. App Review Information

### Contact

- First name: `[Reviewer contact first name]`
- Last name: `[Reviewer contact last name]`
- Email: `[Monitored review email]`
- Phone: `[Review contact phone with country code]`

### Demo account

- Username: `[Non-expiring App Review driver account]`
- Password: `[App Review password]`

Do not use a personal, administrator, or production customer account. Keep the account active throughout review and ensure it has a wallet or test card state that permits a session.

### Review notes

> Electra Hub is an EV charging driver application. The initial map, charger discovery, connector details, pricing, and directions are available without an account. Charging sessions, favorites, recent chargers, payments, receipts, subscriptions, notifications, profile management, and Sparky require the demo account supplied above.
>
> Payments in the app pay for physical EV charging services consumed outside the app. They do not unlock digital content or app functionality.
>
> Location access is optional and used to sort nearby chargers. If location permission is declined, the reviewer can browse the map manually.
>
> To test a charging session without physical charging hardware:
> 1. Sign in with the review account.
> 2. Open `[review station name]` and select `[connector name]`.
> 3. Select the test wallet or saved test card and tap Start Charging.
> 4. Open the simulator link shown on the active charging screen if the submitted review workflow requires unplugging.
> 5. Stop the session and unplug in the simulator to generate the receipt.
>
> Stable test charger: `[charger ID]` / `[connector ID]`.
> Simulator URL: `[review-only simulator URL or instructions]`.
> The Electra Hub backend and test charger will remain available throughout App Review.

Attach a short screen recording if the simulator transition is not obvious to a reviewer.

## 9. App Privacy Draft

This is a starting inventory, not a legal declaration. Confirm each item against backend retention, Firebase settings, third-party SDK behavior, and the published privacy policy before selecting answers in App Store Connect.

| Data category | Likely data | Primary purpose | Linked to identity? |
|---|---|---|---|
| Contact Info | Name, email address, phone number | Account creation and support | Yes |
| Precise Location | Current location coordinates | Nearby charger discovery and sorting | Verify server retention; coordinates are sent in discovery requests |
| Financial Info | Payment token/card metadata, wallet state | Physical charging payment | Yes |
| Purchases | Charging transactions, top-ups, receipts | App functionality and accounting | Yes |
| User Content | Sparky prompts and contact/support messages | Assistance and support | Yes |
| Identifiers | User/account ID, device and push token | Authentication, session ownership, notifications | Yes |
| Usage Data | Product interaction and screen events | Firebase Analytics and product improvement | Verify Firebase configuration |
| Diagnostics | Crash or performance information | Reliability | Verify enabled Firebase collection and SDK behavior |

The app should not declare tracking unless data is linked across other companies' apps or websites for advertising or measurement. Verify this rather than assuming Firebase Analytics is automatically non-tracking.

## 10. Export Compliance Draft

The current app uses operating-system and SDK networking for HTTPS/TLS, authentication, and push notification transport. If it uses only standard encryption provided by Apple and standard HTTPS libraries, it will commonly qualify for an exemption, but the Account Holder must answer App Store Connect's export questions based on the final binary and legal guidance.

After confirmation, add `ITSAppUsesNonExemptEncryption` with the correct Boolean value to avoid repeated export questions. Do not set it to `false` until all cryptography and bundled SDK behavior have been verified.

## 11. Accessibility Submission

Evaluate and declare only capabilities verified on physical devices:

- VoiceOver labels and navigation order
- Voice Control support
- Larger Text/Dynamic Type
- Sufficient contrast
- Differentiation without color alone
- Reduced Motion behavior for charging animations
- Landscape behavior on iPad

Do not claim support solely because the UI is implemented in SwiftUI.

## 12. Current Submission Blockers

### Blocker 1: Equivalent privacy-preserving login

The app currently presents Google and Facebook login for the user's primary account, but no equivalent Apple/privacy-preserving login option was found. Before submission, implement Sign in with Apple or another option that fully satisfies App Review Guideline 4.8, including private email support and equivalent placement. Add the Sign in with Apple capability and backend token exchange.

### Blocker 2: Support page

The marketing site has a project inquiry form, but the App Store Support URL should provide driver support contact information. Publish the dedicated support page described above before entering the final URL.

### Blocker 3: Privacy manifest and declarations

No app-owned `PrivacyInfo.xcprivacy` file was found. Audit required-reason APIs used by the app and bundled SDKs, add a target privacy manifest where required, and ensure App Store privacy answers include Firebase Analytics, Firebase Messaging, authentication providers, and all backend collection.

### Blocker 4: Final review fixtures

Create a non-expiring App Review account and a stable test charger/connector. Verify that start, live updates, stop/unplug, receipt generation, payments, notifications, and account deletion work from the production review build.

### Blocker 5: Security configuration review

The app currently contains an App Transport Security exception allowing insecure HTTP loads for `electrahub.net` and its subdomains. Remove the exception unless a documented production endpoint strictly requires it. App Store distribution should use HTTPS-only production services.

## 13. Final Submission Checklist

- [ ] Replace every square-bracket placeholder
- [ ] Implement the Guideline 4.8-compliant login option
- [ ] Publish and validate the driver support page
- [ ] Complete App Privacy answers from a verified data-flow inventory
- [ ] Add and validate the privacy manifest
- [ ] Confirm export compliance and encryption declaration
- [ ] Confirm legal entity, copyright, content rights, and DSA trader status
- [ ] Complete the current Apple age-rating questionnaire
- [ ] Verify account deletion in the submitted build
- [ ] Remove unnecessary insecure transport exceptions
- [ ] Verify APNs production entitlement and Firebase production project
- [ ] Test the archive on physical iPhone and iPad devices
- [ ] Validate all screenshot content against the submitted build
- [ ] Keep the demo account, APIs, and test charger available during review
- [ ] Upload the archive and verify no App Store Connect processing warnings

## 14. Apple References

- App information: <https://developer.apple.com/help/app-store-connect/reference/app-information/app-information>
- Platform version metadata: <https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information>
- Product page guidance: <https://developer.apple.com/app-store/product-page/>
- App privacy: <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- Age rating: <https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/>
- App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
