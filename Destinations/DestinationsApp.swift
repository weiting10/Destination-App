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
                        .environment(visitedStore)
                        .transition(.opacity)
                }
            }
        }
    }
}
