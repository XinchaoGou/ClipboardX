import Foundation

/// Constants for the GitHub Releases–based updater.
enum UpdateConfig {
    static let repoOwner = "XinchaoGou"
    static let repoName = "ClipboardX"
    static let assetFileName = "ClipboardX-macos.zip"
    static let appBundleName = "ClipboardX.app"
    static let installPath = "/Applications/ClipboardX.app"

    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    static var userAgent: String { "ClipboardX-Updater" }

    /// Background check interval (24 hours).
    static let checkInterval: TimeInterval = 86_400
}
