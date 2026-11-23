//
//  DestinationsApp.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/19/26.
//
import SwiftUI
import SwiftData

@main
struct DestinationsApp: App {
    let destinations = Destinations()

    /// App lock state (PIN in the Keychain, on/off flag in UserDefaults).
    @State private var appLock = AppLock()

    var body: some Scene {
        WindowGroup {
            // RootView runs the splash, then Welcome (first run) or Home, and applies the theme and the lock.
            RootView()
                .environment(destinations)
                .environment(appLock)
        }
        // Creates the on-disk SwiftData store (PlacePhoto is included through the relationship).
        .modelContainer(for: [VisitedPlace.self, Postcard.self])
    }
}
