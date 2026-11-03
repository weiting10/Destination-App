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

    // The welcome screen shows only the first time the app is used. Tapping Continue stores
    // this flag on the device (UserDefaults), so later launches go straight to the home screen.
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenWelcome {
                    WelcomeView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasSeenWelcome = true
                        }
                    }
                    .transition(.opacity)
                } else {
                    HomeView()
                        .environment(destinations)
                        .transition(.opacity)
                }
            }
        }
        // Creates the on-disk SwiftData store (PlacePhoto is included through the relationship).
        .modelContainer(for: VisitedPlace.self)
    }
}
