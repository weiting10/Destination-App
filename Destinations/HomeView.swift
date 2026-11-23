//
//  HomeView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//

// This is the home screen and the starting point. “Places I’ve been” opens the visited list,
// “My Postcards” opens the postcard gallery, and “Get your next destination” picks a random
// destination and opens its page. The toolbar has About (info) and Settings (gear).

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Destinations.self) private var destinations
    @State private var showDestination = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "airplane.departure")
                    .font(.system(size: 70))
                    .foregroundStyle(.tint)
                    .flipsForRightToLeftLayoutDirection(true)   // the plane takes off toward the reading direction

                Text("Ready for your next adventure?")
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                NavigationLink {
                    VisitedPlacesView()
                } label: {
                    Text("Places I've been")
                        .font(.title2.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    PostcardGalleryView()
                } label: {
                    Label("My Postcards", systemImage: "envelope.fill")
                        .font(.title3.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button {
                    destinations.randomize()
                    showDestination = true
                } label: {
                    Text("Get your next destination")
                        .font(.title3.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("background_color").ignoresSafeArea())
            .navigationDestination(isPresented: $showDestination) {
                DestinationView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        InfoView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(Text("About"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("Settings"))
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(Destinations())
        .environment(AppLock())
        .accentTint()
        .modelContainer(for: [VisitedPlace.self, Postcard.self], inMemory: true)
}
