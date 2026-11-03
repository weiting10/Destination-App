# Core Location in Digz

For a reader who has never seen this project. Digz is an iOS app that stores apartment listings. When someone posts a listing, the app is meant to record where the poster is standing (latitude and longitude). The provided file `LocationVM.swift` is the only place that talks to Core Location. It is kept exactly as supplied. This document explains it and lists its problems (IDs refer to `docs/BUGLIST.md`).

## Core Location in plain words

- **`CLLocationManager`** is the object you ask for the device's position. You do not get an answer back from a method call. You give it a *delegate* (an object with agreed method names), and it calls those methods when something happens.
- **`CLLocation`** is one reading: latitude, longitude, `horizontalAccuracy` (the error radius in metres; a negative number means the reading is invalid) and a `timestamp`.
- **Authorization.** The user must allow location use. The status is one of: not asked yet, restricted (blocked by parental controls or device management), denied, allowed while the app is in use, allowed always. Since iOS 14 the user may also allow only *approximate* location (`accuracyAuthorization == .reducedAccuracy`), which is off by kilometres.
- **Privacy string.** The app must declare why it wants location, in its Info settings. Without the text, iOS does not show the permission prompt.

## What `LocationVM.swift` does, in order

`LocationVM` is a "view model": an object a SwiftUI screen watches. Anything marked `@Published` makes the screen redraw when it changes.

1. **Line 14**: creates one `CLLocationManager`.
2. **Lines 16-21**: published state: the latest `location` (optional), the `authStatus`, two alert flags (`restrictedAlertPresenting`, `deniedAlertPresenting`), and `enabled`.
3. **Lines 24-29, `init`**: asks for best accuracy, a 10 m distance filter (no new reading until the device moved 10 m), and makes itself the delegate.
4. **Lines 31-35, `start()`**: asks for "when in use" permission, starts continuous location updates, sets `enabled = true`.
5. **Lines 37-43, `stop()`**: stops updates, clears `location` (on the main queue), sets `enabled = false`.
6. **Lines 48-68, `locationManagerDidChangeAuthorization`**: Core Location calls it when permission changes (and when the manager is first set up). It copies the new status to `authStatus` and raises the denied or restricted alert flag.
7. **Lines 70-72, `didFailWithError`**: prints the error. Nothing else.
8. **Lines 74-80, `didUpdateLocations`**: takes the newest reading and publishes it as `location`.

The class does not decide anything about apartments. It only turns "where is the device" into a published `location` value. A screen must read `location`, copy latitude and longitude into a post, and call `stop()`.

## What must be true elsewhere for it to work

- **Privacy string:** key `NSLocationWhenInUseUsageDescription` with a human-readable reason. Without it no prompt appears and `location` stays nil (B-011). In Digz it is set as the build setting `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` (target, Build Settings, or Info tab; the project generates its Info.plist).
- **Someone must own and start it:** a screen creates it (for example as a `@StateObject`) and calls `start()`. In Digz: `AddApartmentView` and `ContentView` (see "How Digz uses it").
- **Alerts:** a screen must bind alerts to the two flags, or the denied/restricted cases are silent.
- **Simulator:** the simulator has no real GPS. Set one in the Simulator menu, Features, Location (menu wording may differ by version). With "None", no readings arrive. To re-test the first-run prompt, reset permission with `xcrun simctl privacy booted reset location`, or erase the simulator.
- **Threads:** a `CLLocationManager` delivers its callbacks on the thread it was created on, which needs a run loop. If `LocationVM` is created on the main thread (normal for SwiftUI), the callbacks come on the main thread, which makes the `DispatchQueue.main.async` hops redundant but harmless. `start()` and `stop()` should be called from the main thread (B-005).

## Dated compared with iOS 26?

Nothing in the file is deprecated. It uses the current pair (instance `authorizationStatus` plus `locationManagerDidChangeAuthorization`); the older class-method and `didChangeAuthorization` forms are the deprecated ones. The file is, however, written in an older style:

- `ObservableObject` and `@Published` instead of the Observation framework (`@Observable`, iOS 17).
- Delegate callbacks with `DispatchQueue.main.async` instead of Swift concurrency. The async sequence `CLLocationUpdate.liveUpdates()` (iOS 17) and `CLServiceSession` (iOS 18) are the newer route. For one fix per post, `requestLocation()` (a one-shot request, much older) fits better than continuous updates.

I did not verify any iOS 26-specific Core Location change. Whether this matters for Digz: not for correctness. It matters only through concurrency checking (below), and the file is staying as given.

## Problems found

Concrete items are in `docs/BUGLIST.md`: B-002 (concurrency), B-003 (alert at launch), B-004 (`enabled` can lie), B-005 (threading and a stop race), B-006 (accuracy and staleness not checked, approximate location ignored), B-007 (errors only printed), B-008 (continuous best-accuracy updates), B-011 (privacy string), B-012/B-013 (cosmetic, dated).

## What the build is expected to report

**Still not observed in a build log.** Project settings confirmed from `project.pbxproj`: Default Actor Isolation = MainActor, Approachable Concurrency = Yes, Swift 5 language mode, deployment target iOS 26.5. With these, expect a clean build or a warning only. Background: new projects in Xcode 26 default to main-actor isolation with Approachable Concurrency, so `LocationVM` becomes main-actor isolated implicitly. Either it builds clean (the protocol conformance is inferred as main-actor isolated), or it shows a diagnostic that a main-actor method "cannot be used to satisfy nonisolated protocol requirement", which is a warning and, in Swift 6 language mode, an error (B-002). The result depends on target build settings (Default Actor Isolation, Approachable Concurrency, Swift Language Version). Rule: do not turn concurrency checking off or lower the deployment target to hide it.

## How Digz uses it (screens built, Prompts 8, 9, 11)

Two places own a `LocationVM`, each as a `@StateObject`:

| owner | starts | stops | binds the alerts? |
|---|---|---|---|
| `AddApartmentView` (the sheet) | `.onAppear` | Save (before dismiss), Cancel, `.onDisappear` (also covers swipe-down) | yes: denied alert with **Open Settings** / **Continue without location**; restricted alert |
| `ContentView` (sort by distance) | when "Nearest to me" is picked, or "Update my location" | after the **first usable fix**, when switching back to "Newest first", when the app leaves the foreground | no (B-003: the flag is raised at creation); shows an inline row with Open Settings / Show newest |

Rules every caller follows, because `LocationVM` stays as given:

1. **Copy the reading before `stop()`.** `stop()` clears `location` asynchronously (B-005).
2. **Filter readings:** `horizontalAccuracy >= 0` and `timestamp` less than 120 s old (B-006). Show the accuracy to the user, which makes an approximate-location grant (± km) visible.
3. **Never wait forever.** Every "Finding your location…" state has a way out: Save without location (confirmation dialog), Cancel, or Show newest (B-007).
4. **Denied is not a dead end.** Open Settings via `UIApplication.openSettingsURLString`; the action still works without location.
5. **One fix is enough** for a post or a sort. Turn GPS off as soon as you have it (B-008).

## Test notes (from the retired LocationTestView, kept here)

`LocationTestView` (file `Locationtestview.swift`) was the spike screen used for Prompts 1 to 5. It showed authorization (with raw value), the `enabled` flag, an update counter (`onChange(of: vm.location)`), latitude/longitude to 6 decimals, horizontal accuracy and timestamp, with Start/Stop buttons and the two alerts bound. It was deleted in Prompt 9 once the real screens replaced it. Its checks now run on the Add sheet:

1. **First run / not determined:** reset with `xcrun simctl privacy booted reset location wtan10-p-2.Digz` (or Settings › General › Transfer or Reset › Reset Location & Privacy). Open Add: the system prompt appears. *No prompt?* Check the Info key is still in the build settings (B-011); the console shows a message about `NSLocationWhenInUseUsageDescription`.
2. **Allow While Using:** with Features › Location › Custom Location (e.g. 43.1306, −77.6260), the sheet shows a map, coordinates and accuracy within a second or two. Breakpoint in `AddApartmentView.save()` on `let fix = usableFix`: inspect `vm.location?.coordinate`, `horizontalAccuracy`, `timestamp`; thread = main (Thread 1).
3. **Stationary location → one update:** `distanceFilter = 10` means a fixed custom location yields a single reading. That's expected, not a hang.
4. **Moving:** Features › Location › City Run. Coordinates change and the preview map follows (MapView B-001 fix).
5. **None:** Features › Location › None. The sheet stays on "Finding your location…". Save → "No location yet" dialog → Save without location → post has the "No location" placeholder.
6. **Deny:** reset, then Don't Allow. Alert with Open Settings appears; the Location row says the post will save without a map; Save works.
7. **GPS really stops:** breakpoint (or a symbolic breakpoint on `-[CLLocationManager stopUpdatingLocation]`) is hit on Save, Cancel and swipe-down. The location arrow in the simulator's status bar disappears shortly after.

## Without `LocationVM`: a modern one-fix reader (iOS 18+)

For a project that doesn't have `LocationVM.swift`. **Not compiled in Digz**; verify before relying on it. Still needs the same Info key.

```swift
import CoreLocation
import Observation

@MainActor @Observable
final class OneFixLocation {
    var location: CLLocation?
    var denied = false
    private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        task = Task {
            // Asks for "when in use" if not decided yet; keeps the grant alive.
            let session = CLServiceSession(authorization: .whenInUse)
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if update.authorizationDenied { denied = true; break }
                    if let loc = update.location, loc.horizontalAccuracy >= 0 {
                        location = loc
                        break                       // one fix, then stop
                    }
                }
            } catch { /* cancelled or failed: location stays nil */ }
            session.invalidate()
        }
    }

    func stop() { task?.cancel(); task = nil }
}
```

Why this shape: no delegate, no `DispatchQueue` hops (the loop runs on the main actor), stopping is task cancellation, and breaking out of the loop ends updates automatically, so the B-005/B-008 problems can't happen.

## Differences in another project (for Destinations, Prompt 12)

To be filled in by the Destinations session: anything about permission timing, data model or threading that worked differently there.
