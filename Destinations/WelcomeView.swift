//
//  WelcomeView.swift
//  Destinations
//
// The welcome screen shown only on the first launch. It shows the app name,
// a short mission statement, and a Continue button that moves on to the home screen.

import SwiftUI

struct WelcomeView: View {

    /// Called when the user taps Continue
    var onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // App name at the top
            Text("My Little Travel Journal")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("arrow_color"))
                .padding(.horizontal, 30)

            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundStyle(Color("arrow_color"))

            // Brief, slightly poetic mission statement
            Text("Every journey leaves a little magic behind. Keep your footprints, your favorite photos, and your quiet notes close, so the places you've loved can always find their way back to you.")
                .font(.system(size: 20, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 36)

            Spacer()

            // Cute Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.title3.bold())
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color("arrow_color"), in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background_color").ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
