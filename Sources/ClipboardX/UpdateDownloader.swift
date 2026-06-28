import Foundation

enum UpdateDownloader {
    enum DownloadError: LocalizedError {
        case downloadFailed
        case extractFailed
        case missingAppBundle

        var errorDescription: String? {
            switch self {
            case .downloadFailed: "Could not download the update."
            case .extractFailed: "Could not extract the update archive."
            case .missingAppBundle: "Archive does not contain \(UpdateConfig.appBundleName)."
            }
        }
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ClipboardX/Updates", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func downloadAndExtract(assetURL: URL, session: URLSession = .shared) async throws -> URL {
        let zipURL = cacheDirectory.appendingPathComponent(UpdateConfig.assetFileName)
        let extractRoot = cacheDirectory.appendingPathComponent("extract-\(UUID().uuidString)", isDirectory: true)

        try? FileManager.default.removeItem(at: zipURL)
        try? FileManager.default.removeItem(at: extractRoot)
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)

        var request = URLRequest(url: assetURL)
        request.setValue(UpdateConfig.userAgent, forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DownloadError.downloadFailed
        }

        try FileManager.default.moveItem(at: tempURL, to: zipURL)
        try extractZip(at: zipURL, to: extractRoot)

        let appBundle = extractRoot.appendingPathComponent(UpdateConfig.appBundleName, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: appBundle.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DownloadError.missingAppBundle
        }
        return appBundle
    }

    private static func extractZip(at zipURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipURL.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DownloadError.extractFailed
        }
    }
}
