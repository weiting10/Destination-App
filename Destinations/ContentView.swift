//
//  ContentView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//


import SwiftUI

struct ContentView: View {

    @Environment(Destinations.self) private var destinations
    @State private var firstLine = "Where would you like to go?"
    @State private var rotation = 360.0
    private var animation: Animation {
        .easeInOut(duration: 1.0)
        .speed(0.1)
        .repeatForever(autoreverses: true)
    }

    var body: some View {

        // Always read from the model so the screen can't go stale.
        let result = destinations.current()

        VStack {

            Text("Recommender")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            Text(firstLine)
                .font(.system(size: 28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Image(result.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .rotation3DEffect(.degrees(rotation),
                                  axis: (x: 0.0, y: 1.0, z: 0.0))
                .onAppear {
                    withAnimation(animation) { rotation = 0 }
                }

            Spacer()

            Text(result.destination)
                .font(.system(size: 34, weight: .bold))

            Text(result.description)
                .padding(.horizontal, 30)

            Spacer()
            Spacer()

            HStack(spacing: 40) {

                Button {
                    destinations.previous()
                    firstLine = "Where would you like to go?"
                } label: {
                    Image(systemName: "arrowshape.left.fill")
                }

                Button("Select") {
                    firstLine = destinations.select()
                }

                Button {
                    destinations.next()
                    firstLine = "Where would you like to go?"
                } label: {
                    Image(systemName: "arrowshape.right.fill")
                }

            }
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(Color("arrow_color"))
            .padding(.horizontal, 30)
            .padding(.bottom, 20)

        }
        .background(Color("background_color"))
        .navigationBarTitleDisplayMode(.inline)
    }

}

#Preview {
    NavigationStack {
        ContentView()
    }
    .environment(Destinations())
}
