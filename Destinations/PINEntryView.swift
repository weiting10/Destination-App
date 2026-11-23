//
//  PINEntryView.swift
//  Destinations
//
//  The reusable PIN pieces: title, dots, message line and number pad.
//  Used by the lock screen (LockView) and the Settings sheet (PINSheet).
//

import SwiftUI

struct PINEntryView: View {

    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    /// A fixed length submits automatically on the last digit.
    /// nil means "choose 4 to 6 digits" and shows a checkmark key instead.
    let length: Int?
    var message: Text? = nil
    /// Disable the pad and show a countdown while too many wrong tries are being punished.
    var checksLockout = false
    /// Increase to shake the dots and play an error haptic.
    var shakeTrigger = 0
    @Binding var pin: String
    let onSubmit: (String) -> Void

    @Environment(AppLock.self) private var appLock

    static let minLength = 4
    static let maxLength = 6

    var body: some View {
        // Re-renders every second so the countdown ticks and the pad re-enables by itself.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let wait = checksLockout ? appLock.lockoutRemaining(at: context.date) : 0

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                    if let subtitle {
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)

                PINDots(filled: pin.count, total: length ?? Self.maxLength)
                    .keyframeAnimator(initialValue: 0.0, trigger: shakeTrigger) { dots, offset in
                        dots.offset(x: offset)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(-14, duration: 0.06)
                            LinearKeyframe(14, duration: 0.08)
                            LinearKeyframe(-10, duration: 0.08)
                            LinearKeyframe(6, duration: 0.07)
                            LinearKeyframe(0, duration: 0.06)
                        }
                    }

                Group {
                    if wait > 0 {
                        Text("Too many tries. Try again in \(Duration.seconds(wait).formatted(.units(allowed: [.minutes, .seconds], width: .wide))).")
                    } else if let message {
                        message
                    } else {
                        Color.clear
                    }
                }
                .font(.callout)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)

                PINPad(showsNext: length == nil,
                       nextEnabled: pin.count >= Self.minLength,
                       onDigit: add,
                       onDelete: { if !pin.isEmpty { pin.removeLast() } },
                       onNext: { onSubmit(pin) })
                    .disabled(wait > 0)
                    .opacity(wait > 0 ? 0.4 : 1)
            }
        }
        .sensoryFeedback(.error, trigger: shakeTrigger)
    }

    private func add(_ digit: Int) {
        let limit = length ?? Self.maxLength
        guard pin.count < limit else { return }
        pin.append(String(digit))

        // Auto-submit on the last digit, after a short pause so the last dot is seen filling in.
        if let length, pin.count == length {
            let entered = pin
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                onSubmit(entered)
            }
        }
    }
}

// MARK: - Dots

struct PINDots: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                    .overlay(Circle().stroke(.tint, lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
        }
        .environment(\.layoutDirection, .leftToRight)    // dots fill left to right in Arabic too
        .accessibilityElement()
        .accessibilityLabel(Text("\(filled) of \(total) digits entered"))
    }
}

// MARK: - Number pad

struct PINPad: View {
    var showsNext = false
    var nextEnabled = false
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    var onNext: () -> Void = {}

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { digitKey($0) }
                }
            }
            HStack(spacing: 22) {
                if showsNext {
                    Button(action: onNext) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(PadKeyStyle())
                    .disabled(!nextEnabled)
                    .accessibilityLabel(Text("Next"))
                } else {
                    Color.clear.frame(width: PadKeyStyle.size, height: PadKeyStyle.size)
                }

                digitKey(0)

                Button(action: onDelete) {
                    Image(systemName: "delete.backward")
                }
                .buttonStyle(PadKeyStyle(filled: false))
                .accessibilityLabel(Text("Delete"))
            }
        }
        // Phone keypads keep 1-2-3 left to right in Arabic as well.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            onDigit(digit)
        } label: {
            Text(digit, format: .number)      // shows Arabic-Indic digits in Arabic
        }
        .buttonStyle(PadKeyStyle())
    }
}

struct PadKeyStyle: ButtonStyle {
    static let size: CGFloat = 72
    var filled = true

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: Self.size, height: Self.size)
            .background(
                Circle().fill(.tint.opacity(configuration.isPressed ? 0.35 : (filled ? 0.15 : 0)))
            )
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.35)
    }
}
