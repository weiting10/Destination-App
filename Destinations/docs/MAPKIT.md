# MapKit in SwiftUI (Xcode 26, iOS 26): showing a place and naming one

**Audience:** an engineer or AI agent adding a map or a place lookup to a SwiftUI app. Nothing here depends on a particular project.

**Evidence level.** Section 1-3 come from reading a small provided `Map` view and from Apple's current API shape; **the map view was never run** by the author, so treat those parts as reviewed, not tested. Section 4 (reverse geocoding) is used in a second app and its API names come from Apple developer-forum posts and a WWDC25 summary; the code has not been run at the time of writing. Items marked **[unverified]** need a check in your own project.

## 1. The pieces

- **`Map`**: the SwiftUI map view (modern API from iOS 17). Content on the map is a `MapContentBuilder` closure.
- **`CLLocationCoordinate2D`**: a latitude/longitude pair. `import MapKit` makes it available.
- **`MKCoordinateRegion`**: which part of the world to show: centre plus size (for example in metres).
- **`Marker`**: a pin with a label.
- No privacy key and no location permission are needed to **display** a map, because it does not use the device's location. (A blue dot would.)

## 2. Showing one place with a pin

```swift
import SwiftUI
import MapKit

struct PlaceMap: View {
    var title: String
    var coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 50, longitudinalMeters: 50))) {
            Marker(title, coordinate: coordinate)
        }
    }
}
```

Notes and pitfalls:
- `initialPosition` is read **once**. If the same view instance later receives a different coordinate the map will not recentre. Give the view a new identity (for example `.id(coordinate-based value)`) or drive the camera with a `position:` binding **[unverified: not run]**.
- 50 m is street level; use a few kilometres for a city.
- The view takes a non-optional coordinate. If your data may lack one, do not create the map for that item and show a placeholder; a fake (0,0) points at the ocean off West Africa, and an invalid coordinate has undefined results.
- Tiles are downloaded, so the map can stay blank offline or in a restricted simulator. Whether the simulator draws 3D buildings is unconfirmed.
- Do not use a live interactive `Map` for every row of a long list: each one loads tiles and takes touches. Use a static snapshot (`MKMapSnapshotter`) for thumbnails **[unverified: not used]**.
- Pointless wrappers (a `ZStack` around one view) are harmless; an empty label gives an unlabeled pin.

## 3. Is it dated?

No. `Map(initialPosition:)`, the content builder and `Marker` are current and not deprecated, and `#Preview` is current. Nothing here needs an iOS 26-specific API for a simple pin, though I did not exhaustively check what iOS 26 added.

## 4. Turning a coordinate into a place name (reverse geocoding)

`CLGeocoder` and `CLPlacemark` are **deprecated in iOS 26**. The replacement is MapKit's `MKReverseGeocodingRequest`, which returns `MKMapItem` values. You need `import MapKit` (and `import CoreLocation` for `CLLocation`).

```swift
import CoreLocation
import MapKit

func placeName(for location: CLLocation) async -> String? {
    guard let request = MKReverseGeocodingRequest(location: location) else { return nil }   // the initializer can fail
    guard let item = try? await request.mapItems.first else { return nil }
    return item.addressRepresentations?.cityWithContext ?? item.address?.shortAddress
}
```

What you get back **[API names from forum posts and a WWDC25 summary; verify in Xcode]**:
- `MKMapItem.addressRepresentations` (optional) with `cityWithContext` (for example "Cupertino, CA", adapts to the device's locale and region), `cityName`, `regionName` (the **country**, despite the name) and `fullAddress(includingRegion:singleLine:)`.
- `MKMapItem.address` (optional `MKAddress`) with `fullAddress` and `shortAddress`.
- Structured fields such as street or postal code, which `CLPlacemark` used to give, are **not** available as separate values any more. Do not split a formatted string with commas to rebuild them; build display text from `addressRepresentations` instead.
- If your compiler says `mapItems` is not an async property, a completion-handler form `request.getMapItems { items, error in ... }` also exists **[unverified]**; wrap it in a continuation if you need async/await.

Practical rules:
- It needs a **network** and can return zero items or throw. Always leave the user a way to type the value.
- One request per user action; do not geocode in a loop or on every location update **[Apple rate-limits geocoding; exact limits unverified]**.
- Show the result in an editable field, not as a final answer: names for the same spot vary (neighbourhood, suburb, city).
- Do not save coordinates if you only need the name, and say so on screen.

## 5. Checklist

1. Display only: no key, no permission, a valid non-optional coordinate, network available.
2. Naming a place: reverse geocode with `MKReverseGeocodingRequest`, handle nil/empty/throw, let the user edit.
3. Never use `CLGeocoder` in new iOS 26 code.
4. Run it in the simulator with a set location (see CORELOCATION.md section 7) and also with the network off.
