//
//  CurrentPlaceFinder.swift
//  Destinations
//
//  One-shot "where am I right now?" helper for the Add a place sheet.
//  1. The user taps a LocationButton (see AddPlaceSheet), which grants one-time location permission.
//  2. findCurrentPlace() asks Core Location for a single fix (requestLocation).
//  3. The fix is turned into a readable place name with MapKit's reverse geocoder.
//  Nothing is stored here and nothing keeps running: one tap, one lookup.
//

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

    /// True while we have asked the standard permission prompt and are waiting for the answer.
    private var waitingForPermission = false

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // a place name does not need metre accuracy
        manager.delegate = self
    }

    /// Call this from the LocationButton's action.
    /// If the button granted one-time permission, the status is already "when in use" and we just ask for a fix.
    /// If it did not (observed in the iOS 26.5 simulator: status stayed 0), fall back to the standard prompt,
    /// which needs NSLocationWhenInUseUsageDescription in the target's Info.
    func findCurrentPlace() {
        let status = manager.authorizationStatus
        print("findCurrentPlace: authorization status \(status.rawValue)")   // 0 notDetermined, 2 denied, 4 whenInUse
        state = .locating

        switch status {
        case .notDetermined:
            waitingForPermission = true
            manager.requestWhenInUseAuthorization()   // the answer arrives in locationManagerDidChangeAuthorization
        case .denied, .restricted:
            state = .failed("Location is turned off for this app. Allow it in Settings, or type the place.")
        default:
            manager.requestLocation()   // one fix, then Core Location stops by itself
        }
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("Authorization changed: status \(status.rawValue)")

        // Also called once when the manager is set up; only act if we are waiting for the prompt's answer.
        guard waitingForPermission else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            waitingForPermission = false
            manager.requestLocation()
        case .denied, .restricted:
            waitingForPermission = false
            state = .failed("Location wasn't allowed. Please type the place instead.")
        default:
            break   // still notDetermined
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let code = (error as NSError).code
        let status = manager.authorizationStatus.rawValue
        print("Error getting location: code \(code), authorization status \(status), \(error.localizedDescription)")

        var message: String
        if let clError = error as? CLError, clError.code == .denied {
            message = "Location wasn't allowed. Please type the place instead."
        } else {
            message = "Couldn't find your location. Please try again or type the place."
        }
        #if DEBUG
        message += " [debug: code \(code), status \(status)]"   // temporary: remove once the cause is found
        #endif
        state = .failed(message)
    }
}
