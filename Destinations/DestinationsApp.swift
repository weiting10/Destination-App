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

    // the welcome screen shows each time the app is opened fresh
    @State private var showWelcome = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showWelcome {
                    WelcomeView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showWelcome = false
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
