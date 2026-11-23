//
//  SplashView.swift
//  Destinations
//
//  The animated splash that follows the launch screen. Its first frame matches
//  LaunchScreen.storyboard exactly (icon 120×120 in the screen center, copyright line
//  24 pt above the bottom safe area), so the hand-off is invisible. Then:
//  1. the icon pops, 2. an airplane flies across (right-to-left in Arabic),
//  3. the app name fades in. About 2 seconds; tap anywhere to skip.
//

import SwiftUI

struct SplashView: View {

    let onFinished: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var iconScale = 1.0
    @State private var flightTrigger = 0
    @State private var titleVisible = false
    @State private var finished = false

    private struct Flight {
        var x: Double
        var y: Double
    }

    var body: some View {
        GeometryReader { geo in
            let rightToLeft = layoutDirection == .rightToLeft
            let edge = geo.size.width / 2 + 60
            let start = rightToLeft ? edge : -edge

            ZStack {
                Color("background_color")

                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale)
                    .accessibilityHidden(true)

                Text("My Little Travel Journal")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .offset(y: titleVisible ? 110 : 125)
                    .opacity(titleVisible ? 1 : 0)

                // The airplane always points the way it flies.
                Image(systemName: "airplane")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                    .scaleEffect(x: rightToLeft ? -1 : 1, y: 1)
                    .keyframeAnimator(initialValue: Flight(x: start, y: -150),
                                      trigger: flightTrigger) { plane, flight in
                        plane.offset(x: flight.x, y: flight.y)
                    } keyframes: { _ in
                        KeyframeTrack(\.x) {
                            CubicKeyframe(-start, duration: 1.2)
                        }
                        KeyframeTrack(\.y) {
                            CubicKeyframe(-190, duration: 0.6)
                            CubicKeyframe(-150, duration: 0.6)
                        }
                    }
                    .accessibilityHidden(true)
            }
            // Offsets are plain screen coordinates here; the direction is handled above.
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("© 2026 Weiting Tan. All rights reserved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await play() }
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { iconScale = 1.18 }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { iconScale = 1.0 }

        flightTrigger += 1
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeOut(duration: 0.5)) { titleVisible = true }

        try? await Task.sleep(for: .milliseconds(1200))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
        .accentTint()
}
