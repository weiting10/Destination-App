//  DestinationsApp.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.

// This screen comes from "Get your next destination". It shows a randomly generated destination’s photo, name and description.

import SwiftUI

struct DestinationView: View {
    @Environment(Destinations.self) private var destinations
    @Environment(\.dismiss) private var dismiss

    @State private var rotation = 360.0

    private var animation: Animation {
        .easeInOut(duration: 1.0)
        .speed(0.1)
        .repeatForever(autoreverses: true)
    }

    var body: some View {
        let result = destinations.current()

        VStack {
            Spacer()

            Image(result.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .rotation3DEffect(.degrees(rotation), axis: (x: 0.0, y: 1.0, z: 0.0))
                .animation(animation, value: rotation)   // animates only this image
                .onAppear { rotation = 0 }               // no withAnimation

            Spacer()

            Text(result.destination)
                .font(.system(size: 34, weight: .bold))

            Text(result.description)
                .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                }
                .tint(Color("arrow_color"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .transaction { $0.animation = nil }          // never animate the Back button
        }
        .background(Color("background_color").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        DestinationView()
            .environment(Destinations())
    }
}
