# Destinations DECISIONS

Status: **Confirmed** = stated by the developer. **Assumed** = chosen by the assistant, awaiting the developer's veto.

| date | decision | options considered | why |
|------|----------|--------------------|-----|
| 2026-11-02 | Feature: when adding a visited place, offer a shortcut that fills in the user's current location. Confirmed. | Other location/maps ideas (a map of visited places, coordinates saved per place) were not chosen. | Developer's choice; smallest change that uses the location notes. |
| 2026-11-02 | Use `LocationButton` for permission and a one-shot `CLLocationManager.requestLocation()` for the fix. Assumed. | Standard `requestWhenInUseAuthorization()` flow with alert flags (the Digz class); continuous `CLLocationUpdate.liveUpdates()`. | The shortcut is one tap and one lookup; no tracking, no stored authorization state, no permission prompt at launch. Developer asked to incorporate LocationButton or Core Location. |
| 2026-11-02 | The shortcut fills in the place **name** only. No coordinates are stored, so the `VisitedPlace` model and existing saved data are unchanged. Assumed. | Add optional `latitude`/`longitude` to `VisitedPlace` (an additive change that should load old data as nil, **[unverified]**) to enable maps later. | Smallest change; nothing to migrate. Revisit when a map screen is wanted. |
| 2026-11-02 | The add flow changes from an alert with a text field to a sheet (`AddPlaceSheet`). Assumed. | Keep the alert. | An alert is meant for plain buttons and text fields and is not a reliable place for a `LocationButton`. |
| 2026-11-02 | Place name format is MapKit's `cityWithContext` (for example "Kyoto, Japan"), falling back to a short address. The user can edit it before tapping Add. Assumed. | Street address; point-of-interest name. | A travel diary records places at city level. |
| 2026-11-02 | Reverse geocoding uses `MKReverseGeocodingRequest`, not `CLGeocoder`. Confirmed by documentation. | `CLGeocoder`. | `CLGeocoder` is deprecated in iOS 26 and the app targets iOS 26.5. |
| 2026-11-02 | `desiredAccuracy` is 100 m. Assumed. | Best accuracy. | A city name does not need it; less accuracy is faster and uses less battery. |
| 2026-11-02 | The privacy key `NSLocationWhenInUseUsageDescription` is **not** added yet. Assumed. | Add it now. | A third-party source says `LocationButton` does not need it **[unverified]**. Test first; if no dialog appears or the lookup fails as denied, the developer adds the key in Xcode (target, Info tab) using the wording in CORELOCATION.md section 2. |
| 2026-11-02 | `CORELOCATION.md` and `MAPKIT.md` copied into `docs/`; `CORELOCATION.md` gained section 12 and a caveat about the key; `MAPKIT.md` rewritten as a standalone note with a reverse-geocoding section. Confirmed. | Link instead of copy. | Prompt 12 requires the notes to stand alone. |

Not created yet: `AGENTS.md`, `AGENDA.md`, `README.md` (this project had only `BUGLIST.md`).
