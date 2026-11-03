# Adding Core Location to a SwiftUI app (Xcode 26, iOS 26)

**Audience:** an engineer or AI agent who must add "get the user's current location" to a SwiftUI app and get it right the first time. Nothing here depends on any particular project.

**Status and evidence.** The delegate-based approach below was built and run in the iOS simulator (iPhone 17 Pro, iOS 26.5) in a new Xcode 26 project. The first version (permission prompt, readings on screen) was confirmed working by the developer. The final version of the class in section 4 adds fixes described in section 9 and has **not yet been run**; run the hand test in section 8 before trusting it. Nothing was tested on a physical device. Section 12 describes a second, different use (a one-tap, one-time lookup behind `LocationButton`) written for another app; it has not been run yet either. Items marked **[unverified]** come from documentation or reasoning, not from a run.

## 0. Checklist (do these in order)

1. Add the privacy key `NSLocationWhenInUseUsageDescription` with a real sentence (section 2). Without it the standard flow does nothing and nothing tells you why. (A one-tap `LocationButton` flow, section 12, may not need it; test.)
2. Add the class from section 4 (keep `import Combine`).
3. Create it once per screen that needs it, on the main thread; call `start()` from a user action, `stop()` when the screen goes away.
4. Bind the two alert flags to alerts.
5. Save coordinates only when `isUsable(_:)` is true.
6. In the simulator set a location (section 7), then run the hand test (section 8).
7. Do not change build settings or lower the deployment target to make a concurrency or import error go away (section 6).

## 1. The moving parts

- **`CLLocationManager`**: asks iOS for readings. Answers come to its *delegate*, not as return values.
- **`CLLocation`**: one reading: `coordinate.latitude/longitude`, `horizontalAccuracy` (metres; **negative means invalid**), `timestamp`.
- **Authorization**: the user must allow location. Status is a `CLAuthorizationStatus`.
- **Privacy key**: text in the app's Info settings, shown in the permission prompt.
- **A view model** (below): wraps the manager and publishes state a SwiftUI screen can watch.

## 2. The privacy key

- **Key:** `NSLocationWhenInUseUsageDescription` (Xcode label: "Privacy - Location When In Use Usage Description").
- **Why:** the class calls `requestWhenInUseAuthorization()`. iOS shows the permission prompt only if this key exists. If it is missing there is **no prompt, no error, the status stays `notDetermined` (0), and no readings arrive**. A UI flag you set yourself (such as "enabled") will still flip, which looks like progress but isn't.
- **Other keys not needed** for when-in-use. `NSLocationAlwaysAndWhenInUseUsageDescription` is for "always" authorization, which this code never requests. `NSLocationTemporaryUsageDescriptionDictionary` is only for temporarily requesting full accuracy **[unverified for this class: not used]**.
- **Wording:** say what it is used for and, if true, that it is stored. Example: "The app uses your current location to mark where your listing is. The location is saved with your post." The text is shown to the user, so write it for them.
- **Where in Xcode 26:** Project navigator, click the blue project icon, under TARGETS select the app target, open the **Info** tab, in "Custom iOS Target Properties" hover a row, click **+**, choose "Privacy - Location When In Use Usage Description", type the sentence as the value. Equivalent: **Build Settings**, set "All", search "Location When In Use", fill the setting (it maps to `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`) **[unverified: label seen from memory]**.
- Stop and run again after adding it; the key is baked into the build.
- **Exception to test:** `LocationButton` (section 12) shows the system's own one-time dialog, and one third-party article says no privacy string is needed for it **[unverified]**. Apple's authorization guide says the standard `requestWhenInUseAuthorization()` path fails immediately without the key. If a `LocationButton` tap shows no dialog or `requestLocation()` fails with a denied error, add the key.

## 3. The authorization flow

`CLAuthorizationStatus` raw values: 0 notDetermined, 1 restricted, 2 denied, 3 authorizedAlways, 4 authorizedWhenInUse. `accuracyAuthorization.rawValue`: 0 full, 1 reduced (approximate).

- `requestWhenInUseAuthorization()` does something **only while the status is `notDetermined`**. It returns immediately; the answer arrives later at `locationManagerDidChangeAuthorization(_:)`.
- That delegate method is **also called when the manager is set up**, before the user did anything. Do not treat that call as "the user just changed something": if you raise an alert from it unconditionally, an app that was denied in a previous run shows the alert at launch.
- The prompt offers Allow Once, Allow While Using App, Don't Allow, and a Precise Location switch. **Allow Once** reports `authorizedWhenInUse` during the session and goes back to `notDetermined` after the app has been closed **[behaviour as documented; confirm in your run]**.
- After **Don't Allow** (2) the app cannot show the prompt again, and `requestWhenInUseAuthorization()` is a no-op. The callback will not fire again either, so when the user taps "use my location" while already denied you must check the status yourself in `start()` and raise the alert there. Direct the user to Settings (`UIApplication.openSettingsURLString`).
- The user can change the permission later in Settings. iOS may restart the app when that happens **[unverified]**. If the app keeps running, the delegate callback fires with the new status.
- **Restricted** (1) means a device policy blocks it, usually not changeable by the user.
- **Approximate location** (reduced accuracy): readings are off by kilometres. Do not save them as a precise point. `isPrecise` and `horizontalAccuracy` expose it.

## 4. Reference implementation

```swift
import Foundation
import CoreLocation
import Combine


class LocationVM: NSObject, ObservableObject {

    private let lm = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var isPrecise = true          // false if the user allowed approximate location only
    @Published var lastError: String?        // latest failure message, cleared by the next fix

    @Published var restrictedAlertPresenting = false
    @Published var deniedAlertPresenting = false
    @Published var enabled = false           // true only while updates run or the permission answer is pending

    // what counts as a usable fix when saving coordinates (see isUsable)
    var maxHorizontalAccuracy: CLLocationAccuracy = 100   // metres
    var maxFixAge: TimeInterval = 30                      // seconds

    // true between start() and stop(); alerts are only raised while the user wants location
    private var wantsLocation = false


    override init () {
        super.init()
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.distanceFilter = 10
        lm.delegate = self
    }

    func start() {
        wantsLocation = true
        lastError = nil
        lm.requestWhenInUseAuthorization()          // does nothing unless the status is notDetermined
        let status = lm.authorizationStatus
        handleAuthorization(status, precise: lm.accuracyAuthorization == .fullAccuracy)
        if status == .notDetermined {
            lm.startUpdatingLocation()              // permission prompt is pending
            enabled = true
        }
    }

    func stop() {
        wantsLocation = false
        lm.stopUpdatingLocation()
        location = nil
        enabled = false
    }

    /// true if a reading is accurate and recent enough to save with a post.
    func isUsable(_ loc: CLLocation) -> Bool {
        loc.horizontalAccuracy >= 0
            && loc.horizontalAccuracy <= maxHorizontalAccuracy
            && -loc.timestamp.timeIntervalSinceNow <= maxFixAge
    }

    // Single place that reacts to an authorization status.
    private func handleAuthorization(_ status: CLAuthorizationStatus, precise: Bool) {
        authStatus = status
        isPrecise = precise

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if wantsLocation {
                lm.startUpdatingLocation()
                enabled = true
            }
        case .denied:
            lm.stopUpdatingLocation()
            enabled = false
            if wantsLocation {
                deniedAlertPresenting = true
            }
        case .restricted:
            lm.stopUpdatingLocation()
            enabled = false
            if wantsLocation {
                restrictedAlertPresenting = true
            }
        default: break
        }
    }
}

extension LocationVM: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        let status = manager.authorizationStatus
        let precise = manager.accuracyAuthorization == .fullAccuracy
        DispatchQueue.main.async {
            self.handleAuthorization(status, precise: precise)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print("Error getting location: " + error.localizedDescription)
        let message = error.localizedDescription
        DispatchQueue.main.async {
            self.lastError = message
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            DispatchQueue.main.async {
                guard self.enabled else { return }   // drop a late fix that arrives after stop()
                self.lastError = nil
                self.location = loc
            }
        }
    }
}
```

API surface a screen uses: `location`, `authStatus`, `isPrecise`, `lastError`, `enabled`, `restrictedAlertPresenting`, `deniedAlertPresenting`, `start()`, `stop()`, `isUsable(_:)`. Keep it that small; it makes swapping the implementation later (section 10) cheap.

Design notes:
- `location` publishes **every** fix. The *policy* (`isUsable`: accurate within 100 m and no older than 30 s, both adjustable properties) is applied by the caller. Rejecting fixes inside the class risks showing no location at all, with no way to see why. The thresholds are guesses for "a pin on a street"; tune them.
- `enabled` means "updates are running or the permission answer is pending". It is not proof that coordinates exist; check `location != nil`.
- `wantsLocation` separates "the app is just alive" from "the user asked for location". Alerts only fire for the latter.
- `stop()` clears state synchronously. The update block checks `enabled`, so a fix that arrives after `stop()` cannot repopulate `location`.
- `distanceFilter = 10` means a new reading only after about 10 m of movement. `desiredAccuracy = kCLLocationAccuracyBest` with continuous updates costs battery and keeps the status-bar location arrow on; always call `stop()`.

## 5. Using it in a SwiftUI screen

```swift
struct PostScreen: View {
    @StateObject private var location = LocationVM()

    var body: some View {
        Form {
            Button("Use my current location") { location.start() }
            // show location.location, location.lastError, location.isPrecise as needed
        }
        .alert("Location denied", isPresented: $location.deniedAlertPresenting) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Allow location for this app in Settings to attach it to your post.")
        }
        .onDisappear { location.stop() }
    }

    func usableCoordinate() -> CLLocationCoordinate2D? {
        guard let loc = location.location, location.isUsable(loc) else { return nil }
        return loc.coordinate
    }
}
```

- Put each `.alert` on a **different** view. Two `.alert` modifiers on one view can conflict.
- Create the view model where the screen is built, not at app launch, so the manager does not exist before location is needed.
- If saving without coordinates is allowed, `usableCoordinate()` returning `nil` is a normal outcome (denied, approximate, no fix yet).

## 6. Threading and Swift concurrency (Xcode 26)

- A `CLLocationManager` delivers delegate callbacks on the thread it was created on (which must have a run loop). Create the view model on the main thread (normal for SwiftUI) and the callbacks arrive on main. The `DispatchQueue.main.async` hops in the class are then redundant at runtime, but they keep every published change on main regardless, and the compiler cannot know the manager is on main, so they were left in. `start()` and `stop()` must be called from main.
- New Xcode 26 projects default to main-actor isolation with approachable concurrency enabled, so a class like this is implicitly main-actor isolated. The reference class compiled and ran in such a project once `import Combine` was added **(compiler warnings were not reviewed [unverified])**.
- **Do not turn off concurrency checking or lower the deployment target to hide a diagnostic.** If you get "Main actor-isolated instance method ... cannot be used to satisfy nonisolated protocol requirement" (a warning, and an error in the Swift 6 language mode), the documented approach is to mark the delegate methods `nonisolated` and hop to the main actor yourself. Not tested here **[unverified]**.
- **Missing import trap:** `@Published` and `ObservableObject` come from **Combine**. A file that imports only Foundation and CoreLocation fails in a new Xcode 26 project with "Initializer 'init(wrappedValue:)' is not available due to missing import of defining module 'Combine'" and a follow-on "does not conform to 'ObservableObject'". Fix: `import Combine`. (Older projects got it indirectly, which is why code copied from them breaks.)

## 7. Simulator testing

- The simulator has **no real GPS**. With no location set, no readings arrive.
- **Set a point:** Simulator menu, Features, Location, Custom Location, enter latitude and longitude. While running from Xcode you can also use the Simulate Location button in the debug bar.
- **Move:** Features, Location, City Run, City Bike Ride or Freeway Drive. **Stop:** Features, Location, None.
- **Distance filter maths:** 1 degree of latitude is about 111 km, so 0.0001 degree is about 11 m. With a 10 m filter, change latitude by 0.0002 (about 22 m) to get an update and by 0.00003 (about 3 m) to confirm none arrives. The first fix after `start()` should arrive regardless.
- **Reset the permission prompt:** quit the app, then `xcrun simctl privacy booted reset location` (append the bundle identifier to reset only your app). Or in the simulator: Settings, General, Transfer or Reset iPhone, Reset Location & Privacy; or Device menu, Erase All Content and Settings.
- **Settings changes:** in the simulator's Settings app open your app's entry (or Privacy & Security, Location Services) and choose Never, Ask Next Time Or When I Share, or While Using the App. Precise Location has its own switch; the simulator may not honour it **[unverified]**.
- A location you set long before tapping Start may arrive with an old `timestamp`, in which case `isUsable` returns false **[unverified]**.

## 8. Hand test with breakpoints

Set breakpoints on these statements in the reference class (type the expressions in the Xcode debug console at the `(lldb)` prompt; if `Thread` is not found run `expr import Foundation` first):

| # | Where | Type |
|---|-------|------|
| a | in `start()`, the line after `let status = lm.authorizationStatus` | `p status.rawValue`, `po self.wantsLocation`, `po self.enabled` |
| b | first line of `handleAuthorization` | `p status.rawValue`, `po precise`, `po self.wantsLocation`, `po Thread.isMainThread` |
| c | `if wantsLocation` inside the `.denied` case | `po self.wantsLocation` |
| d | the `print` in `didFailWithError` | `po error`, `po (error as NSError).domain`, `p (error as NSError).code` (domain `kCLErrorDomain`: 0 locationUnknown, 1 denied) |
| e | the `DispatchQueue.main.async` line inside `didUpdateLocations` | `po locations.count`, `po loc`, `p loc.horizontalAccuracy`, `p loc.coordinate.latitude`, `p loc.coordinate.longitude`, `po loc.timestamp`, `p -loc.timestamp.timeIntervalSinceNow` (age in s), `po self.isUsable(loc)`, `po Thread.isMainThread` |
| f | `guard self.enabled` inside that block | `po self.enabled`, `po self.location` (still the old value) |
| g | first line of `stop()` | `po self.wantsLocation`, `po self.location`; step over to the end, then `po self.enabled` |

Expected results (prediction until run; replace with observations):

| Case | Expected |
|------|----------|
| Fresh install, launch, tap nothing | (b) hits at set-up with status 0, `wantsLocation` false. No alert. |
| Start, Allow While Using App | (a) status 0, then the prompt. (b) status 4, `wantsLocation` true. (e) a `loc` with small `horizontalAccuracy`. (f) `enabled` true. Screen: coordinates, "Usable: yes". |
| Allow Once | As above. After quitting and relaunching, (b) shows 0 again and the prompt returns on Start. |
| Don't Allow | (b) status 2, (c) `wantsLocation` true, alert shown, `enabled` false, `location` nil. (d) probably code 1. |
| Tap Start again while denied | (a) status 2, then (b) is reached straight from `start()` and the alert appears immediately without any system callback. |
| Denied, then switch to While Using in Settings | If the app keeps running, (b) status 4 with `wantsLocation` true, updates resume by themselves. If it restarted, tap Start. |
| Allowed, then Never in Settings | (b) status 2, alert, updates stop, `enabled` false. |
| Allowed, simulator location None | No fix. (d) may hit with code 0 and `lastError` shows text. |
| Move 22 m / 3 m | 22 m: (e) hits, counter rises. 3 m: no hit. |
| Tap Stop | (g): `wantsLocation` true before, false after; `location` nil; `enabled` false; moving the simulator changes nothing. If a fix is already queued, (f) shows `enabled` false and nothing is published. |
| Precise Location off (if honoured) | (b) `precise` false, "Location precision: approximate", large accuracy, "Usable: no". |
| Leave the screen | `onDisappear` calls `stop()`; the status-bar location arrow goes away. |

## 9. Pitfalls we hit (and the first-time-right fix)

1. **No privacy key**: Start flipped a flag, nothing else happened, no error. Add the key; judge success by coordinates on screen, never by a flag you set yourself.
2. **`import Combine` missing**: two confusing errors (section 6). Add the import.
3. **Wrong code pasted into the wrong file**: the class file was overwritten by a test view and the build said "Cannot find 'LocationVM' in scope" at an odd line and column. When an error points at an unexpected place, open that exact file and check what is in it.
4. **Alert at launch**: the authorization callback also fires at set-up. Gate alerts on "the user asked".
5. **`enabled` lied**: set to true without regard to permission. Make flags describe reality.
6. **Late fix after stop**: a queued main-thread block can set state after `stop()`. Check a flag inside the block.
7. **Silent failures**: failures were only printed. Publish a message.
8. **Trusting every fix**: first fixes can be stale or coarse; approximate authorization gives coordinates off by kilometres. Check accuracy and age before saving.
9. **Continuous updates left running**: always pair `start()` with `stop()`.
10. **Nothing happens in the simulator**: no location was set (section 7).

## 10. When to use the newer APIs instead

`CLLocationUpdate.liveUpdates()` (iOS 17) gives an async sequence of updates, and `CLServiceSession` (iOS 18) lets code declare the authorization it needs; iterating `liveUpdates()` takes an implicit when-in-use session. The privacy key is still required. That route removes the delegate, the main-queue hops and several of the problems above, at the price of learning async/await, task cancellation and the update's diagnostic flags, and of requiring iOS 17/18 or later. Choose it for a new app that targets recent iOS and wants one clean file. Choose the class in this note when you must support older iOS, are copying known-working code, or want the smallest verified change. API details here come from secondary sources; check Apple's documentation before relying on them **[unverified]**.

`@Observable` (iOS 17) can replace `ObservableObject`/`@Published`; screens then own the model with `@State` instead of `@StateObject` and use `@Bindable` for alert bindings.

## 11. Minimal test harness

Show this temporarily from your root view to prove the pipeline before building real screens. Delete it afterwards.

```swift
import SwiftUI
import CoreLocation

struct LocationTestView: View {

    @StateObject private var vm = LocationVM()
    @State private var updateCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEMPORARY: Core Location test")
                .font(.headline)
                .foregroundStyle(.red)

            row("Authorization", Self.describe(vm.authStatus))
            row("enabled flag", vm.enabled ? "true" : "false")
            row("Location precision", vm.isPrecise ? "full" : "approximate")
            row("Updates received", "\(updateCount)")
            row("Latitude", vm.location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "nil")
            row("Longitude", vm.location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "nil")
            row("Horizontal accuracy", vm.location.map { String(format: "%.1f m", $0.horizontalAccuracy) } ?? "nil")
            row("Timestamp", vm.location.map { $0.timestamp.formatted(date: .abbreviated, time: .standard) } ?? "nil")
            row("Fix age (when drawn)", vm.location.map { String(format: "%.0f s", -$0.timestamp.timeIntervalSinceNow) } ?? "nil")
            row("Usable for saving?", vm.location.map { vm.isUsable($0) ? "yes" : "no" } ?? "nil")
            row("Last error", vm.lastError ?? "none")

            HStack(spacing: 16) {
                Button("Start") {
                    updateCount = 0
                    vm.start()
                }
                Button("Stop") {
                    vm.stop()
                }
            }
            .buttonStyle(.borderedProminent)
            .alert("Location denied", isPresented: $vm.deniedAlertPresenting) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Location access is denied. Change it in Settings to continue.")
            }
        }
        .padding()
        .alert("Location restricted", isPresented: $vm.restrictedAlertPresenting) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Location access is restricted on this device.")
        }
        .onChange(of: vm.location) { _, newValue in
            if newValue != nil { updateCount += 1 }
        }
        .onDisappear {
            vm.stop()   // never leave updates running when the screen goes away
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private static func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined (0)"
        case .restricted: "restricted (1)"
        case .denied: "denied (2)"
        case .authorizedAlways: "authorizedAlways (3)"
        case .authorizedWhenInUse: "authorizedWhenInUse (4)"
        @unknown default: "unknown (\(status.rawValue))"
        }
    }
}
```

## 12. Variation: one tap, one lookup behind `LocationButton`

Use this when location is a **user-initiated shortcut** (a "use my current location" button in a form) and nothing needs to track movement. It removes the long-lived pieces of sections 3-6: no authorization state machine in your code, no alert flags, no continuous updates, no `stop()` to forget.

**What `LocationButton` is.** A SwiftUI button from the CoreLocationUI framework (iOS 15+). Tapping it grants **one-time** authorization, like "Allow Once". It does **not** return a location: in its action you fetch the position with Core Location. After the user agrees to the button once, later taps grant one-time authorization without another alert. `import CoreLocationUI` is required (with member import visibility on, SwiftUI alone is not enough).

```swift
LocationButton(.currentLocation) {
    finder.findCurrentPlace()     // your Core Location call
}
.symbolVariant(.fill)
.labelStyle(.titleAndIcon)
```

**Flow.** Tap, system one-time dialog, button action runs, `CLLocationManager.requestLocation()` (one fix, then it stops by itself), the delegate gets `didUpdateLocations` once or `didFailWithError`, optional reverse geocoding to a place name (see MAPKIT.md), state updates, the screen reacts.

**Reference class** (used in a travel-diary app to fill in a place name; `@Observable`, one-shot):

```swift
import Foundation
import CoreLocation
import MapKit
import Observation

@Observable
final class CurrentPlaceFinder: NSObject {

    enum State: Equatable {
        case idle
        case locating
        case found(String)      // a place name such as "Kyoto, Japan"
        case failed(String)     // a message the user can read
    }

    var state: State = .idle

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // a place name does not need metre accuracy
        manager.delegate = self
    }

    /// Call this from the LocationButton's action. The button has just granted one-time permission.
    func findCurrentPlace() {
        state = .locating
        manager.requestLocation()   // one fix, then Core Location stops by itself
    }

    private func lookUpName(for location: CLLocation) async {
        // CLGeocoder is deprecated in iOS 26; MKReverseGeocodingRequest is its replacement.
        guard let request = MKReverseGeocodingRequest(location: location) else {
            state = .failed("Couldn't work out the place name. Please type it instead.")
            return
        }
        do {
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else {
                state = .failed("No place name found here. Please type it instead.")
                return
            }
            // cityWithContext is e.g. "Cupertino, CA"; fall back to a short address if there is no city.
            if let name = item.addressRepresentations?.cityWithContext ?? item.address?.shortAddress {
                state = .found(name)
            } else {
                state = .failed("No place name found here. Please type it instead.")
            }
        } catch {
            state = .failed("Couldn't look up the place name (are you online?). Please type it instead.")
        }
    }
}

extension CurrentPlaceFinder: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else {
            state = .failed("Couldn't get a usable location. Please try again.")
            return
        }
        Task {
            await lookUpName(for: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print("Error getting location: " + error.localizedDescription)
        if let clError = error as? CLError, clError.code == .denied {
            state = .failed("Location wasn't allowed. Please type the place instead.")
        } else {
            state = .failed("Couldn't find your location. Please try again or type the place.")
        }
    }
}
```

Owned by the screen with `@State private var finder = CurrentPlaceFinder()` (iOS 17 Observation pattern), and the screen reacts with `.onChange(of: finder.state) { ... }`.

**How it differs from the section 4 class**
- `@Observable` instead of `ObservableObject`/`@Published`: no `import Combine`, and the owner uses `@State` instead of `@StateObject`.
- No `authStatus`, alert flags, `enabled` or `wantsLocation`: there is no prolonged session. Failure is reported as one `state` value with a readable message. A denied error (`CLError.code == .denied`) is mapped to a "type it instead" message.
- `desiredAccuracy = kCLLocationAccuracyHundredMeters`: a city name does not need metre accuracy, and less accuracy is faster and cheaper.
- The delegate methods are called directly on the main actor (manager created on main), so there are no `DispatchQueue.main.async` hops; the reverse-geocoding lookup runs in a `Task`.
- Reverse geocoding uses MapKit's `MKReverseGeocodingRequest`, because `CLGeocoder` is deprecated in iOS 26 (MAPKIT.md).
- `requestLocation()` allows one request at a time; calling it again cancels the previous one, so double taps are safe.

**Project facts seen in the app this was written for:** iOS 26.5 deployment target, default actor isolation MainActor, approachable concurrency on, member import visibility on, Swift 5 language mode, Xcode file-system synchronized folders (a new `.swift` file placed in the app folder joins the target automatically). Settings are not changed to make code compile.

**Pitfalls specific to this variation**
- **An alert cannot hold the button.** Alert actions are meant for plain buttons and text fields, so put the `LocationButton` in a **sheet** or in the normal view hierarchy **[unverified that an alert rejects it; a sheet is known to work with ordinary views]**.
- **The tap grants permission, not coordinates.** If the action does nothing, nothing happens.
- **Reverse geocoding needs a network** and can return nothing; always leave the user a way to type the value.
- **Do not store or log the coordinates if you only needed a name**; say so on screen (the app above does).
- Test with a simulated location (section 7); with "None" the fix fails.

**Hand test for this variation** (set breakpoints on `findCurrentPlace`, on the first line of `didUpdateLocations`, on `didFailWithError`, and after `let mapItems = try await request.mapItems`):

| Case | Expected |
|------|----------|
| Custom location set, first tap | System one-time dialog appears; allow. `findCurrentPlace` hits (`po self.state` shows `locating`). `didUpdateLocations` hits with `po locations.count` 1 and `p location.horizontalAccuracy` a small positive number. After the geocoder, `po mapItems.first?.addressRepresentations?.cityWithContext` shows a name such as "Cupertino, CA" and the name field fills in. |
| Tap again | No second dialog (per Apple's docs); same result. |
| Don't allow / dismiss the dialog | `didFailWithError` hits with `p (error as NSError).code` equal to 1; red message "Location wasn't allowed". Typing still works. |
| Simulator location None | Failure message ("Couldn't find your location"); `didFailWithError` code 0 is likely **[unverified]**. |
| Airplane mode or no network after a fix | `didUpdateLocations` hits, the geocoder throws, message about being online. |
| Edit the filled name, tap Add | The edited name is saved, not the one the finder produced. |
| Reset the permission | `xcrun simctl privacy booted reset location com.wtan10.Destinations` (use your bundle id), then tap again to see the dialog. |
