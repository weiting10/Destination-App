# MapKit in Digz: expert note

Written so it stands alone: you can copy this file into another project and add maps from it without reading Digz. "B-" numbers refer to Digz's `docs/BUGLIST.md` and are history, not prerequisites.

## 1. MapKit in plain words

- **MapKit** is Apple's map framework. In SwiftUI the `Map` view draws the map. A *content builder* closure inside it lists what to draw on top (`Marker`, `Annotation`, `MapCircle`, `UserAnnotation`).
- **`CLLocationCoordinate2D`** is a latitude/longitude pair (degrees). It comes from Core Location; `import MapKit` re-exports it. **It is not `Equatable` or `Codable`.** That matters for `onChange` and for storage (sections 4 and 6).
- **`MKCoordinateRegion`** is a centre plus a size. `MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)` is the readable form.
- **`MapCameraPosition`** is what the map is looking at: `.region(...)`, `.camera(...)`, `.item(...)`, `.userLocation(fallback:)`, `.automatic`.
- **`Marker`** is the system balloon pin with a text label. An empty label gives an unlabeled pin.
- **Showing a map needs no location permission.** Only the user's blue dot (`UserAnnotation`, `.userLocation`) or `MapUserLocationButton` uses the device's location, and then the Core Location rules apply (see CORELOCATION.md).

## 2. The `MapView` in this project

`MapView(address:coord:showMarker:meters:interactive:)`, in `Digz/MapView.swift`:

| parameter | default | meaning |
|---|---|---|
| `address` | required | Marker label and accessibility text. `""` = unlabeled pin. |
| `coord` | required | Centre and marker position. |
| `showMarker` | `true` | Draw the pin. |
| `meters` | `50` | Width/height of the visible region. The default is kept from the provided file; callers pass their own (section 5). |
| `interactive` | `true` | `false` = no pan/zoom/rotate, and taps pass through to whatever contains the map (list rows). |

The camera is a `@State` `MapCameraPosition` bound with `Map(position:)`. An `onChange` on `[coord.latitude, coord.longitude, meters]` moves it, with animation, when the input changes.

Where it is used: the detail screen (500 m, interactive, labelled marker), list-row thumbnails (400 m, `interactive: false`, unlabeled marker, 72×72 pt) and the Add sheet's location preview (300 m, not interactive).

## 3. Lesson 1: `initialPosition` is read once (B-001)

The provided `MapView` used `Map(initialPosition: .region(...))`. Fed a live location, **the marker moved but the camera stayed put**. The marker is content and re-evaluates on every body pass. `initialPosition` is the *starting* camera only: after the first appearance the map owns its camera (the user may have panned), so SwiftUI ignores later values.

Ways to make a map follow:

1. **`@State var position: MapCameraPosition` + `Map(position: $position)` + `onChange` that sets it.** Smooth, keeps the map instance, lets the user pan in between. Chosen here.
2. **Change the view's identity**, `.id(someKeyFromCoord)`. Forces a new `Map` on each change: simple, no MapView edit, but it flickers, reloads tiles and loses the user's zoom.
3. **`.userLocation(followsHeading:fallback:)`** for "follow *me*". MapKit tracks the device itself; it needs location permission and only works for the user's own position, not a stored coordinate.

Watch out: `onChange(of:)` needs `Equatable`, which `CLLocationCoordinate2D` isn't. Watch `[lat, lon]` (a `[Double]`), or wrap the coordinate in a small `Equatable` struct.

## 4. Lesson 2: maps inside a list row (B-010)

A `Map` in every row costs:

- **Memory and GPU**: each live map is an `MKMapView` underneath with its own tile cache and render surface. `List` is lazy, so only visible rows (about 8 to 10) are alive, but scrolling creates and destroys maps constantly. Tiles are downloaded on first show, so fast scrolling shows blank squares filling in.
- **Scrolling**: creating a map view is not free. On older devices you can feel the hitch as rows appear.
- **Touch handling**: an interactive map swallows the drag and tap, so the row's `NavigationLink` doesn't fire and vertical scrolling can grab the map instead of the list.

Options:

| | live `Map`, interaction off | `MKMapSnapshotter` image |
|---|---|---|
| code | 1 line: `interactionModes: []` + `.allowsHitTesting(false)` | async snapshot per row, cache by coordinate, placeholder while loading, redo for dark mode |
| cost per row | a full map view while visible | a `UIImage`; nothing live |
| looks | identical to detail, dark mode automatic | static image, must regenerate on appearance change |
| right when | tens of rows | hundreds of rows, or scrolling feels heavy |

**Digz uses the live map with interaction off** (DECISIONS.md, Assumed). It's simplest and fine for a personal list. Switch to snapshots if a 20+ row list stutters on device: `MKMapSnapshotter.Options` with `region`, `size`, `traitCollection`, then `try await snapshotter.start()` → `snapshot.image`, and draw the pin yourself at `snapshot.point(for: coord)`.

## 5. Region size: 50 m is too tight

| use | size | why |
|---|---|---|
| Detail map | **500 m** | Shows the block and nearby streets, so the user can recognise the area. 50 m is one building: with GPS error often 10 to 65 m, the pin can sit on the wrong building and nothing around it helps. |
| Row thumbnail (72 pt) | **400 m** | At 72 pt, 50 m is a grey roof with no context. A few streets is what identifies a place at a glance. |
| "Where am I" preview | 300 m | Enough to confirm "yes, that's here". |

Rule of thumb: region ≥ 5 × horizontal accuracy, and big enough to include one named street.

## 6. Storing coordinates

Store `latitude: Double?` and `longitude: Double?`, not `CLLocationCoordinate2D`:

- `CLLocationCoordinate2D` isn't `Codable`, so SwiftData can't store it directly. Two `Double`s are plain columns you can query and sort.
- Optionals say "no location" honestly. Never use 0,0 as "missing": it's a real point in the Gulf of Guinea, and maps happily show it (B-009).
- A computed `coordinate: CLLocationCoordinate2D?` returns `nil` unless both are present and `CLLocationCoordinate2DIsValid` passes. Views then write `if let c = item.coordinate { MapView(...) } else { placeholder }`. **Never construct a map without a valid coordinate.**

## 7. What must be true elsewhere

- **Network**: tiles download. Offline (or a simulator with no network) shows a beige grid with the marker. Cached areas still render.
- **Threads**: SwiftUI builds views on the main actor; nothing MapKit-specific to handle. `MKMapSnapshotter.start()` is async and safe to call from a `.task`.
- **Previews**: `Map` renders in Xcode previews when the Mac is online.
- **Simulator**: Features › Location sets where the *device* is. It doesn't affect a map showing a stored coordinate. 3D buildings appear only at close zoom with `.mapStyle(.standard(elevation: .realistic))`, and only in supported cities.
- **Accessibility**: a map is opaque to VoiceOver. Give it `accessibilityLabel("Map of <address>")`.

## 8. Dated compared with iOS 26?

`Map(position:interactionModes:)`, the content builder, `Marker` and `MapCameraPosition` are the iOS 17+ SwiftUI API and current. The older `Map(coordinateRegion:)` initialisers are deprecated, so avoid them in code you copy. On iOS 26, MapKit also took over geocoding from Core Location: `MKReverseGeocodingRequest` / `MKGeocodingRequest` replace the deprecated `CLGeocoder`. Not used in Digz; check the exact API before relying on it.

## 9. Test procedure

1. Previews: `MapView` "Detail size" and "Row thumbnail" render; `ApartmentView` both variants.
2. Detail: open a post. Map centred on it, labelled marker, block-level zoom. Pan away, go back, reopen: re-centred.
3. List: 20+ rows, scroll fast. Tapping the thumbnail opens the detail (taps pass through), and no row grabs the scroll.
4. A post without coordinates shows the placeholder in the row and on the detail, never a map at 0,0.
5. Add sheet with a moving simulated location (Features › Location › City Run): the preview map follows (lesson 1).
