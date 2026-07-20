# ElectraHub Site Google Play Availability Message

## Request

Replace the inactive Google Play destination on the ElectraHub website with a clear coming-soon experience.

## Change

- Converted the Google Play badge from a placeholder link into an accessible button.
- Reused the existing site modal pattern to display the Android availability message.
- Added keyboard focus handling so the close control receives focus on open and the Google Play badge regains focus on close.
- Kept the iOS TestFlight CTA separate and unchanged.

## Verification

- The Google Play badge opens a modal headed `Google Play is coming soon`.
- Escape, the close control, and clicking the backdrop close the modal.
- The badge does not navigate to an empty URL.
