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
    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }
    @Published var skippedVersion: String? {
        didSet {
            if let skippedVersion {
                defaults.set(skippedVersion, forKey: Keys.skippedVersion)
            } else {
                defaults.removeObject(forKey: Keys.skippedVersion)
            }
        }
    }
    @Published var lastUpdateCheckDate: Date? {
        didSet {
            if let lastUpdateCheckDate {
                defaults.set(lastUpdateCheckDate, forKey: Keys.lastUpdateCheckDate)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheckDate)
            }
        }
    }

    private init() {
        maxHistoryCount = defaults.object(forKey: Keys.maxHistoryCount) as? Int ?? 1000
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        restorePreviousClipboardAfterPaste = defaults.object(forKey: Keys.restoreClipboard) as? Bool ?? false
        pollInterval = defaults.object(forKey: Keys.pollInterval) as? Double ?? 0.4
        autoCheckUpdates = defaults.object(forKey: Keys.autoCheckUpdates) as? Bool ?? true
        skippedVersion = defaults.string(forKey: Keys.skippedVersion)
        lastUpdateCheckDate = defaults.object(forKey: Keys.lastUpdateCheckDate) as? Date
    }

    private enum Keys {
        static let maxHistoryCount = "maxHistoryCount"
        static let launchAtLogin = "launchAtLogin"
        static let restoreClipboard = "restorePreviousClipboardAfterPaste"
        static let pollInterval = "pollInterval"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let skippedVersion = "skippedVersion"
        static let lastUpdateCheckDate = "lastUpdateCheckDate"
    }
}
