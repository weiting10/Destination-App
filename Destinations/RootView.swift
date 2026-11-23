//
//  RootView.swift
//  Destinations
//
//  Decides what the window shows and handles everything app-wide:
//  launch screen → animated splash → Welcome (first run only) → Lock (if on) → Home.
//  Also applies the accent color and appearance, and locks the app when it goes
//  to the background (with a cover that hides the content in the app switcher).
//

import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // The welcome screen shows only the first time the app is used. Tapping Continue stores
    // this flag on the device (UserDefaults), so later launches go straight to the home screen.
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system

    /// The splash plays once per cold launch (RootView lives as long as the app).
    @State private var showSplash = true
    @State private var overlay = LockOverlayWindow()
    /// Changing this rebuilds Home from scratch (used after erasing all data,
    /// so no screen is left showing a place that no longer exists).
    @State private var homeID = UUID()

    var body: some View {
        ZStack {
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasSeenWelcome = true
                    }
                }
                .transition(.opacity)
            } else {
                HomeView()
                    .id(homeID)
                    .transition(.opacity)
            }

            // Hides Home on a locked launch, so it never flashes before the lock window appears.
            if appLock.isLocked {
                Color("background_color").ignoresSafeArea()
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .accentTint()
        .onAppear {
            appearance.applyToAllWindows()
            updateOverlay()
        }
        .onChange(of: appearance) { _, mode in
            mode.applyToAllWindows()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                appearance.applyToAllWindows()
                appLock.isObscured = false
            case .inactive:
                if appLock.isEnabled { appLock.isObscured = true }
            case .background:
                appLock.lockIfEnabled()
                if appLock.isEnabled { appLock.isObscured = true }
            @unknown default:
                break
            }
        }
        .onChange(of: showSplash) { updateOverlay() }
        .onChange(of: appLock.isLocked) { updateOverlay() }
        .onChange(of: appLock.isObscured) { updateOverlay() }
    }

    /// Shows or hides the lock window. It waits until the splash has finished.
    private func updateOverlay() {
        if !showSplash && (appLock.isLocked || appLock.isObscured) {
            let context = modelContext
            overlay.show(
                LockOverlayContent {
                    eraseAllData(in: context)
                }
                .environment(appLock),
                makeKey: appLock.isLocked
            )
        } else {
            overlay.hide()
        }
    }

    private func eraseAllData(in context: ModelContext) {
        homeID = UUID()                    // close any open diary, sheet or photo first
        DataReset.eraseAll(in: context)
        appLock.turnOff()
    }
}

/// What the lock window shows: the lock screen, with the privacy cover on top while inactive.
private struct LockOverlayContent: View {
    @Environment(AppLock.self) private var appLock
    let onEraseAll: () -> Void

    var body: some View {
        ZStack {
            if appLock.isLocked {
                LockView(onEraseAll: onEraseAll)
            }
            if appLock.isObscured {
                PrivacyCoverView()
                    .transition(.opacity)
            }
        }
        .accentTint()
    }
}
