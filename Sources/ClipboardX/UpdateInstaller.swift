import AppKit
import Foundation

enum UpdateInstaller {
    enum InstallError: LocalizedError {
        case scriptWriteFailed
        case launchFailed

        var errorDescription: String? {
            switch self {
            case .scriptWriteFailed: "Could not prepare the install helper."
            case .launchFailed: "Could not start the install helper."
            }
        }
    }

    /// Replace the installed app and relaunch after this process exits.
    static func installAndRelaunch(newAppBundle: URL) throws {
        let target = UpdateConfig.installPath
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboardx-install-\(UUID().uuidString).sh")

        let shellBody = """
        set -e
        TARGET='\(shellEscaped(target))'
        NEW='\(shellEscaped(newAppBundle.path))'
        for _ in $(seq 1 60); do
          pgrep -x ClipboardX >/dev/null || break
          sleep 0.25
        done
        rm -rf "$TARGET"
        /usr/bin/ditto "$NEW" "$TARGET"
        /usr/bin/open "$TARGET"
        """

        let script: String
        if needsAdministratorPrivileges(forInstallPath: target) {
            script = """
            #!/bin/bash
            /usr/bin/osascript -e 'do shell script "\(appleScriptEscaped(shellBody))" with administrator privileges'
            """
        } else {
            script = "#!/bin/bash\n\(shellBody)"
        }

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()

        NSApp.terminate(nil)
    }

    private static func needsAdministratorPrivileges(forInstallPath path: String) -> Bool {
        let parent = (path as NSString).deletingLastPathComponent
        return !FileManager.default.isWritableFile(atPath: parent)
    }

    private static func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
