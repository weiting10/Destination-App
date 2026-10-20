//
//  DestinationsApp.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
import SwiftUI

@main
struct DestinationsApp: App {
    let destinations = Destinations()
    let visitedStore = VisitedStore()

    // Saved on the device, so the welcome screen only appears on the first launch
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasSeenWelcome {
                    HomeView()
                        .environment(destinations)
                        .environment(visitedStore)
                        .transition(.opacity)
                } else {
                    WelcomeView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasSeenWelcome = true
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
