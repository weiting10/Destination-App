//
//  LockOverlayWindow.swift
//  Destinations
//
//  Shows the lock screen / privacy cover in its own window above everything else.
//  A normal SwiftUI overlay would sit *under* any open sheet or full-screen photo,
//  so a separate UIWindow at alert level is the only way to cover them all.
//

import SwiftUI
import UIKit

@MainActor
final class LockOverlayWindow {

    private var window: UIWindow?

    /// Shows the window (creating it if needed). `makeKey` gives it keyboard/touch focus,
    /// which the lock screen needs; the privacy cover alone doesn't, so a half-typed
    /// note keeps its keyboard when you pull down Control Center.
    func show<Content: View>(_ content: Content, makeKey: Bool) {
        if window == nil {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }

            let newWindow = UIWindow(windowScene: scene)
            newWindow.windowLevel = .alert + 1
            let host = UIHostingController(rootView: content)
            host.view.backgroundColor = .clear
            newWindow.rootViewController = host
            newWindow.overrideUserInterfaceStyle = AppearanceMode.stored.uiStyle
            newWindow.isHidden = false
            window = newWindow
        }
        if makeKey, let window, !window.isKeyWindow {
            window.makeKey()
        }
    }

    /// Fades the window out and gives focus back to the app's main window.
    func hide() {
        guard let closing = window else { return }
        window = nil
        let mainWindow = closing.windowScene?.windows.first { $0 !== closing && $0.windowLevel == .normal }
        UIView.animate(withDuration: 0.25, animations: {
            closing.alpha = 0
        }, completion: { _ in
            closing.isHidden = true
            mainWindow?.makeKey()
        })
    }
}
