# Destinations Bug List

_Last updated: 2026-10-05_

Ranked by severity. Fixed bugs move to the "Fixed" section at the bottom.

## Show-stopper
Crashes, data loss, or anything that blocks the main flow (Home → Destination → Back).

- **BUG-001: App crashes when the previous arrow is tapped on the first destination**
  - Where: `DestinationView.swift`
  - Steps: open the first destination, tap the left arrow
  - Cause: `(index - 1) % count` returns -1 in Swift
  - Status: Fixed (replaced with `previous()` that wraps safely)

## General
Wrong or unexpected behavior that doesn't block the app.

- **BUG-002: Random pick can show the same destination twice in a row**
  - Where: `Destinations.randomize()`
  - Steps: tap "Get your next destination" repeatedly
  - Status: Open

## UI
Layout, spacing, color, animation, and visual polish.

- **BUG-003: Back button moved up and down with the image rotation**
  - Where: `DestinationView.swift`
  - Cause: `withAnimation` in `onAppear` animated the whole view
  - Status: Fixed (animation attached to the image only)

- **BUG-004: Swipe-back gesture disabled**
  - Where: `DestinationView.swift`
  - Cause: system back button is hidden in favor of a custom one
  - Status: Open

## Fixed
- BUG-001, BUG-003 (2026-10-05)