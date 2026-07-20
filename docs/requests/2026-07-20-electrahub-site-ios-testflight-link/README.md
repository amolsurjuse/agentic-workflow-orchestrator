# ElectraHub Site iOS TestFlight Link

## Request

Update the public ElectraHub website's iOS app CTA to use the supplied TestFlight invitation:

`https://testflight.apple.com/join/ZCKy4Xsa`

## Change

- Replaced the placeholder iOS destination in `electra-hub-org-page/index.html`.
- Labelled the CTA as a TestFlight beta link rather than a public App Store download.
- Opened the external TestFlight invitation in a new browsing context with `noopener` protection.

## Verification

- Confirm the rendered iOS CTA points exactly to the supplied TestFlight URL.
- Confirm the existing Google Play CTA is unchanged.
