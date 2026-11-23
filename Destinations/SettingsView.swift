//
//  SettingsView.swift
//  Destinations
//
//  Opened from the gear button on the home screen. Four persisted settings:
//  accent color, appearance, animate destination photo, and app lock.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppLock.self) private var appLock

    @AppStorage(SettingsKey.accentColorHex) private var accentHex = ""
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.animateDestinationPhoto) private var animatePhoto = true

    @State private var pinSheet: PINSheet.Mode?

    /// The ColorPicker works with Color; it is saved as a hex string.
    private var accentBinding: Binding<Color> {
        Binding(
            get: { Theme.accent(fromHex: accentHex) },
            set: { accentHex = $0.hexString }
        )
    }

    /// The toggle doesn't flip by itself: it opens the PIN sheet, and only a
    /// finished sheet actually turns the lock on or off.
    private var lockBinding: Binding<Bool> {
        Binding(
            get: { appLock.isEnabled },
            set: { pinSheet = $0 ? .create : .turnOff }
        )
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)
                if !accentHex.isEmpty {
                    Button("Use the original color") {
                        accentHex = ""
                    }
                }
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("Look")
            }

            Section {
                Toggle("Animate destination photo", isOn: $animatePhoto)
            } header: {
                Text("Destination")
            } footer: {
                Text("Turns the slow, endless 3D spin of the photo on the destination screen on or off.")
            }

            Section {
                Toggle("App lock", isOn: lockBinding)
                if appLock.isEnabled {
                    Button("Change PIN") {
                        pinSheet = .change
                    }
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("When the lock is on, the app asks for your PIN every time you open it or come back to it. A forgotten PIN can't be recovered; the only way back in is to erase all data.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("background_color").ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pinSheet) { mode in
            PINSheet(mode: mode)
                .environment(appLock)
                .accentTint()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppLock())
    .accentTint()
}
