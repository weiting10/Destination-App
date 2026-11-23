//
//  LockView.swift
//  Destinations
//
//  The lock screen shown on launch and when coming back from the background,
//  plus the plain cover that hides the app in the app switcher.
//

import SwiftUI

struct LockView: View {

    @Environment(AppLock.self) private var appLock

    /// Erases places, photos (and later postcards) and removes the lock.
    let onEraseAll: () -> Void

    @State private var pin = ""
    @State private var message: Text?
    @State private var shake = 0
    @State private var confirmingErase = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("My Little Travel Journal")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            PINEntryView(title: "Enter your PIN",
                         length: appLock.pinLength,
                         message: message,
                         checksLockout: true,
                         shakeTrigger: shake,
                         pin: $pin,
                         onSubmit: submit)

            Button("Forgot your PIN?") {
                confirmingErase = true
            }
            .font(.callout)

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background_color").ignoresSafeArea())
        .alert("Erase all data?", isPresented: $confirmingErase) {
            Button("Erase everything", role: .destructive) {
                onEraseAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("There is no way to recover a forgotten PIN. This deletes all your places, photos and notes, and turns the lock off. It can't be undone.")
        }
    }

    private func submit(_ entered: String) {
        switch appLock.unlock(with: entered) {
        case .correct:
            message = nil
        case .wrong(let triesLeft):
            message = Text("Wrong PIN. \(triesLeft) tries left before a delay.")
            shake += 1
        case .lockedOut:
            message = nil          // PINEntryView shows the countdown
            shake += 1
        }
        pin = ""
    }
}

/// Hides the app's content while it is inactive or in the app switcher.
struct PrivacyCoverView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("My Little Travel Journal")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background_color").ignoresSafeArea())
    }
}

#Preview("Lock") {
    LockView(onEraseAll: {})
        .environment(AppLock())
        .accentTint()
}

#Preview("Privacy cover") {
    PrivacyCoverView()
        .accentTint()
}
