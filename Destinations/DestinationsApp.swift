//
//  DestinationsApp.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/19/26.
//
import SwiftUI

@main
struct DestinationsApp: App {
    let destinations = Destinations()
    let visitedStore = VisitedStore()

    // Starts as true on every launch of the app, so the welcome screen
    // shows each time the app is opened fresh (not when it returns from the background).
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
                        .environment(visitedStore)
                        .transition(.opacity)
                }
            }
        }
    }
}
