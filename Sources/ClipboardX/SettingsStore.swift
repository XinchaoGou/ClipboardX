import Foundation
import Combine

/// User-configurable settings, persisted in UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var maxHistoryCount: Int {
        didSet { defaults.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    @Published var restorePreviousClipboardAfterPaste: Bool {
        didSet { defaults.set(restorePreviousClipboardAfterPaste, forKey: Keys.restoreClipboard) }
    }
    @Published var pollInterval: Double {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    private init() {
        maxHistoryCount = defaults.object(forKey: Keys.maxHistoryCount) as? Int ?? 1000
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        restorePreviousClipboardAfterPaste = defaults.object(forKey: Keys.restoreClipboard) as? Bool ?? false
        pollInterval = defaults.object(forKey: Keys.pollInterval) as? Double ?? 0.4
    }

    private enum Keys {
        static let maxHistoryCount = "maxHistoryCount"
        static let launchAtLogin = "launchAtLogin"
        static let restoreClipboard = "restorePreviousClipboardAfterPaste"
        static let pollInterval = "pollInterval"
    }
}
