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

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(destinations)
                .environment(visitedStore)
        }
    }
}
