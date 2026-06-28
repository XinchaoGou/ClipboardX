import AppKit
import Combine
import Foundation

@MainActor
final class AppUpdateController: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, notes: String)
        case downloading
        case error(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastCheckDate: Date?

    private let settings: SettingsStore
    private var pendingRelease: GitHubRelease?
    private var periodicTimer: Timer?
    private var checkTask: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
        lastCheckDate = settings.lastUpdateCheckDate
    }

    deinit {
        periodicTimer?.invalidate()
    }

    func startAutomaticChecks() {
        if settings.autoCheckUpdates {
            checkForUpdates(manual: false)
        }
        schedulePeriodicTimer()
    }

    func checkForUpdates(manual: Bool) {
        guard checkTask == nil else { return }

        status = .checking
        checkTask = Task { [weak self] in
            await self?.performCheck(manual: manual)
            await MainActor.run { self?.checkTask = nil }
        }
    }

    func downloadAndInstallUpdate() {
        guard let release = pendingRelease, let asset = release.updateAsset else { return }

        status = .downloading
        Task {
            do {
                let appBundle = try await UpdateDownloader.downloadAndExtract(assetURL: asset.browserDownloadURL)
                let confirmed = await confirmInstall(version: release.version?.description ?? release.tagName)
                guard confirmed else {
                    status = .updateAvailable(
                        version: release.version?.description ?? release.tagName,
                        notes: release.body
                    )
                    return
                }
                try UpdateInstaller.installAndRelaunch(newAppBundle: appBundle)
            } catch {
                if !Task.isCancelled {
                    status = .error(error.localizedDescription)
                    showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Private

    private func schedulePeriodicTimer() {
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: UpdateConfig.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.settings.autoCheckUpdates else { return }
                self.checkForUpdates(manual: false)
            }
        }
    }

    private func performCheck(manual: Bool) async {
        do {
            let release = try await GitHubReleaseClient.fetchLatestRelease()
            let remoteVersion = release.version
            let currentVersion = AppVersion.current

            lastCheckDate = Date()
            settings.lastUpdateCheckDate = lastCheckDate

            guard let remoteVersion, let currentVersion else {
                status = .error(GitHubReleaseClient.ClientError.invalidVersion.localizedDescription)
                if manual { showErrorAlert(message: status.errorMessage ?? "Invalid version.") }
                return
            }

            if remoteVersion <= currentVersion {
                pendingRelease = nil
                status = .upToDate
                if manual { showUpToDateAlert(version: currentVersion.description) }
                return
            }

            if !manual, settings.skippedVersion == remoteVersion.description {
                status = .idle
                return
            }

            pendingRelease = release
            status = .updateAvailable(version: remoteVersion.description, notes: release.body)
            if manual || settings.autoCheckUpdates {
                presentUpdateAlert(release: release, version: remoteVersion.description)
            }
        } catch {
            pendingRelease = nil
            status = .error(error.localizedDescription)
            if manual { showErrorAlert(message: error.localizedDescription) }
        }
    }

    private func presentUpdateAlert(release: GitHubRelease, version: String) {
        let alert = NSAlert()
        alert.messageText = "ClipboardX \(version) is available"
        alert.informativeText = trimmedNotes(release.body)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download and Install…")
        alert.addButton(withTitle: "Remind Me Later")
        alert.addButton(withTitle: "Skip This Version")

        let choice = alert.runModal()
        switch choice {
        case .alertFirstButtonReturn:
            downloadAndInstallUpdate()
        case .alertThirdButtonReturn:
            settings.skippedVersion = version
            status = .idle
        default:
            break
        }
    }

    private func confirmInstall(version: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Install ClipboardX \(version)?"
        alert.informativeText =
            "ClipboardX will quit and replace \(UpdateConfig.installPath), then relaunch the updated app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showUpToDateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "ClipboardX \(version) is the latest release."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Update check failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func trimmedNotes(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 1200 { return trimmed.isEmpty ? "No release notes." : trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 1200)
        return String(trimmed[..<index]) + "…"
    }
}

private extension AppUpdateController.Status {
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
