//
//  PINSheet.swift
//  Destinations
//
//  The sheet Settings opens for the app lock:
//  - Turn on:  choose a PIN → enter it again
//  - Change:   current PIN → new PIN → enter it again
//  - Turn off: current PIN
//

import SwiftUI

struct PINSheet: View {

    enum Mode: String, Identifiable {
        case create, change, turnOff
        var id: String { rawValue }
    }

    private enum Step {
        case current, new, confirm
    }

    let mode: Mode

    @Environment(AppLock.self) private var appLock
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step
    @State private var pin = ""
    @State private var newPIN = ""
    @State private var message: Text?
    @State private var shake = 0

    init(mode: Mode) {
        self.mode = mode
        _step = State(initialValue: mode == .create ? .new : .current)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                PINEntryView(title: title,
                             subtitle: subtitle,
                             length: length,
                             message: message,
                             checksLockout: step == .current,
                             shakeTrigger: shake,
                             pin: $pin,
                             onSubmit: submit)
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("background_color").ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: Text for each step

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .create: "Turn on app lock"
        case .change: "Change PIN"
        case .turnOff: "Turn off app lock"
        }
    }

    private var title: LocalizedStringKey {
        switch step {
        case .current: "Enter your current PIN"
        case .new: mode == .change ? "Choose a new PIN" : "Choose a PIN"
        case .confirm: "Enter the PIN again"
        }
    }

    private var subtitle: LocalizedStringKey? {
        switch step {
        case .current: nil
        case .new: "4 to 6 digits"
        case .confirm: "Just to make sure"
        }
    }

    private var length: Int? {
        switch step {
        case .current: appLock.pinLength
        case .new: nil
        case .confirm: newPIN.count
        }
    }

    // MARK: Flow

    private func submit(_ entered: String) {
        switch step {
        case .current:
            switch appLock.check(entered) {
            case .correct:
                pin = ""
                message = nil
                if mode == .turnOff {
                    appLock.turnOff()
                    dismiss()
                } else {
                    step = .new
                }
            case .wrong(let triesLeft):
                fail(Text("Wrong PIN. \(triesLeft) tries left before a delay."))
            case .lockedOut:
                fail(nil)
            }

        case .new:
            newPIN = entered
            pin = ""
            message = nil
            step = .confirm

        case .confirm:
            guard entered == newPIN else {
                newPIN = ""
                step = .new
                fail(Text("The PINs didn't match. Please choose one again."))
                return
            }
            let saved = mode == .create ? appLock.turnOn(pin: entered) : appLock.changePIN(to: entered)
            if saved {
                dismiss()
            } else {
                newPIN = ""
                step = .new
                fail(Text("Couldn't save the PIN. Please try again."))
            }
        }
    }

    private func fail(_ text: Text?) {
        message = text
        shake += 1
        pin = ""
    }
}

#Preview {
    PINSheet(mode: .create)
        .environment(AppLock())
        .accentTint()
}
