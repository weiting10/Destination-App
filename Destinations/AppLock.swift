//
//  AppLock.swift
//  Destinations
//
//  The app lock: a 4–6 digit PIN.
//  - Only the on/off flag is kept in UserDefaults (same storage as @AppStorage).
//  - The PIN is never stored as text: the Keychain holds a random salt and SHA-256(salt + PIN).
//  - After 5 wrong tries, each further try is delayed (30 s, doubling, max 5 min).
//    The counter survives restarting the app.
//

import Foundation
import Observation
import Security
import CryptoKit

@MainActor
@Observable
final class AppLock {

    enum CheckResult {
        case correct
        case wrong(triesLeft: Int)
        case lockedOut
    }

    static let freeAttempts = 5

    /// True when the user has turned the lock on in Settings.
    private(set) var isEnabled: Bool
    /// Number of digits in the saved PIN, so the lock screen can submit automatically.
    private(set) var pinLength: Int
    /// True while the lock screen is showing.
    var isLocked: Bool
    /// True while the app is inactive / in the app switcher (hides the content).
    var isObscured = false

    private(set) var failedAttempts: Int
    private(set) var lockoutUntil: Date?

    @ObservationIgnored private let defaults = UserDefaults.standard
    private enum Keys {
        static let failedAttempts = "appLockFailedAttempts"
        static let lockoutUntil = "appLockLockoutUntil"
    }

    init() {
        var enabled = defaults.bool(forKey: SettingsKey.appLockEnabled)
        let record = PINStore.load()

        // Flag on but no PIN in the Keychain: nothing to check against, so turn the lock off.
        if enabled && record == nil {
            enabled = false
            defaults.set(false, forKey: SettingsKey.appLockEnabled)
        }
        // Keychain items survive deleting the app; clear a leftover PIN from an old install.
        if !enabled {
            PINStore.delete()
        }

        isEnabled = enabled
        pinLength = record?.length ?? 4
        isLocked = enabled                     // locked on every cold launch
        failedAttempts = defaults.integer(forKey: Keys.failedAttempts)
        let until = defaults.double(forKey: Keys.lockoutUntil)
        lockoutUntil = until > 0 ? Date(timeIntervalSince1970: until) : nil
    }

    // MARK: Checking the PIN

    /// Whole seconds left before another try is allowed (0 = no delay).
    func lockoutRemaining(at date: Date = .now) -> Int {
        guard let lockoutUntil else { return 0 }
        return max(0, Int(lockoutUntil.timeIntervalSince(date).rounded(.up)))
    }

    /// Checks a PIN and updates the wrong-try counter. Used by the lock screen and by Settings.
    func check(_ pin: String) -> CheckResult {
        if lockoutRemaining() > 0 { return .lockedOut }

        if PINStore.matches(pin) {
            resetAttempts()
            return .correct
        }

        failedAttempts += 1
        if failedAttempts >= Self.freeAttempts {
            let extra = Double(failedAttempts - Self.freeAttempts)
            let seconds = min(30 * pow(2, extra), 300)
            lockoutUntil = Date.now.addingTimeInterval(seconds)
            saveAttempts()
            return .lockedOut
        }
        saveAttempts()
        return .wrong(triesLeft: Self.freeAttempts - failedAttempts)
    }

    /// Lock screen: a correct PIN removes the lock screen.
    func unlock(with pin: String) -> CheckResult {
        let result = check(pin)
        if case .correct = result { isLocked = false }
        return result
    }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    // MARK: Turning it on / off

    @discardableResult
    func turnOn(pin: String) -> Bool {
        guard let record = PINStore.save(pin) else { return false }
        pinLength = record.length
        isEnabled = true
        defaults.set(true, forKey: SettingsKey.appLockEnabled)
        resetAttempts()
        return true
    }

    @discardableResult
    func changePIN(to pin: String) -> Bool {
        guard let record = PINStore.save(pin) else { return false }
        pinLength = record.length
        resetAttempts()
        return true
    }

    /// Removes the PIN and the lock. Also used by "Forgot your PIN?" after the data is erased.
    func turnOff() {
        PINStore.delete()
        isEnabled = false
        isLocked = false
        isObscured = false
        defaults.set(false, forKey: SettingsKey.appLockEnabled)
        resetAttempts()
    }

    // MARK: Wrong-try counter

    private func resetAttempts() {
        failedAttempts = 0
        lockoutUntil = nil
        saveAttempts()
    }

    private func saveAttempts() {
        defaults.set(failedAttempts, forKey: Keys.failedAttempts)
        defaults.set(lockoutUntil?.timeIntervalSince1970 ?? 0, forKey: Keys.lockoutUntil)
    }
}

// MARK: - Keychain storage

/// Stores the salted hash of the PIN in the Keychain (this device only, readable only while unlocked).
enum PINStore {

    struct Record: Codable {
        let salt: Data
        let hash: Data
        let length: Int
    }

    private static let service = (Bundle.main.bundleIdentifier ?? "Destinations") + ".applock"
    private static let account = "pin"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Saves a new PIN (replacing any old one). Returns the record, or nil if the Keychain refused.
    static func save(_ pin: String) -> Record? {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { return nil }

        let record = Record(salt: salt, hash: hash(pin, salt: salt), length: pin.count)
        guard let data = try? JSONEncoder().encode(record) else { return nil }

        delete()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess ? record : nil
    }

    static func load() -> Record? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    static func delete() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    static func matches(_ pin: String) -> Bool {
        guard let record = load() else { return false }
        return hash(pin, salt: record.salt) == record.hash
    }

    private static func hash(_ pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }
}
