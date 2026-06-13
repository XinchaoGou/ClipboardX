import Foundation
import Combine

/// User-configurable settings, persisted in UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    /// Bundle IDs that should never be recorded.
    static let defaultExcludedBundleIDs: [String] = [
        "com.apple.keychainaccess",        // Keychain Access
        "com.agilebits.onepassword7",      // 1Password 7
        "com.1password.1password",         // 1Password 8
        "com.bitwarden.desktop",           // Bitwarden
        "com.apple.Passwords"              // Apple Passwords
    ]

    @Published var maxHistoryCount: Int {
        didSet { defaults.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    @Published var restorePreviousClipboardAfterPaste: Bool {
        didSet { defaults.set(restorePreviousClipboardAfterPaste, forKey: Keys.restoreClipboard) }
    }
    @Published var enablePlainTextPaste: Bool {
        didSet { defaults.set(enablePlainTextPaste, forKey: Keys.plainTextPaste) }
    }
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }
    @Published var pollInterval: Double {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    private init() {
        maxHistoryCount = defaults.object(forKey: Keys.maxHistoryCount) as? Int ?? 1000
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        restorePreviousClipboardAfterPaste = defaults.object(forKey: Keys.restoreClipboard) as? Bool ?? false
        enablePlainTextPaste = defaults.object(forKey: Keys.plainTextPaste) as? Bool ?? true
        excludedBundleIDs = defaults.object(forKey: Keys.excludedBundleIDs) as? [String]
            ?? SettingsStore.defaultExcludedBundleIDs
        pollInterval = defaults.object(forKey: Keys.pollInterval) as? Double ?? 0.4
    }

    private enum Keys {
        static let maxHistoryCount = "maxHistoryCount"
        static let launchAtLogin = "launchAtLogin"
        static let restoreClipboard = "restorePreviousClipboardAfterPaste"
        static let plainTextPaste = "enablePlainTextPaste"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let pollInterval = "pollInterval"
    }
}
