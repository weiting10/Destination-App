//
//  AppSettings.swift
//  Destinations
//
//  The four persisted settings and the theme helpers that use them.
//  1. Accent color  (user-selected, stored as a hex string; empty = the original arrow_color)
//  2. Appearance    (System / Light / Dark)
//  3. App lock      (on/off flag only; the PIN itself lives in the Keychain, see AppLock.swift)
//  4. Animate destination photo (turns the endless 3D rotation on or off)
//

import SwiftUI
import UIKit

/// UserDefaults / @AppStorage keys, kept in one place so they can't be mistyped.
enum SettingsKey {
    static let accentColorHex = "accentColorHex"
    static let appearance = "appearance"
    static let appLockEnabled = "appLockEnabled"
    static let animateDestinationPhoto = "animateDestinationPhoto"
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// The value currently saved in UserDefaults.
    static var stored: AppearanceMode {
        AppearanceMode(rawValue: UserDefaults.standard.string(forKey: SettingsKey.appearance) ?? "") ?? .system
    }

    /// Applied to every window (including sheets and the lock window) instead of
    /// .preferredColorScheme, which doesn't reliably switch back to "System".
    @MainActor
    func applyToAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = uiStyle
            }
        }
    }
}

// MARK: - Accent color

enum Theme {
    /// The original color from the asset catalog, used until the user picks another one.
    static let defaultAccent = Color("arrow_color")

    static func accent(fromHex hex: String) -> Color {
        Color(hex: hex) ?? defaultAccent
    }
}

/// Reads the saved accent color and applies it as the tint.
/// Views then use `.tint` / `.foregroundStyle(.tint)` instead of Color("arrow_color").
struct AccentTint: ViewModifier {
    @AppStorage(SettingsKey.accentColorHex) private var accentHex = ""

    func body(content: Content) -> some View {
        content.tint(Theme.accent(fromHex: accentHex))
    }
}

extension View {
    func accentTint() -> some View {
        modifier(AccentTint())
    }
}

extension Color {
    /// "#RRGGBB" → Color. Returns nil for an empty or malformed string.
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    /// Color → "#RRGGBB" (sRGB, clamped).
    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
