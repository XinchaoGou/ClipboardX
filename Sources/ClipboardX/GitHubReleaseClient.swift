import Foundation

struct GitHubRelease: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case prerelease
        case assets
    }

    var version: AppVersion? { AppVersion(tagName) }

    var updateAsset: Asset? {
        assets.first { $0.name == UpdateConfig.assetFileName }
    }
}

enum GitHubReleaseClient {
    enum ClientError: LocalizedError {
        case badResponse(Int)
        case notFound
        case decodeFailed
        case noStableRelease
        case missingAsset
        case invalidVersion

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): "GitHub API returned HTTP \(code)."
            case .notFound: "No releases found for this repository."
            case .decodeFailed: "Could not read the release metadata."
            case .noStableRelease: "Latest release is a pre-release; skipping."
            case .missingAsset: "Release is missing \(UpdateConfig.assetFileName)."
            case .invalidVersion: "Release tag is not a valid version."
            }
        }
    }

    static func fetchLatestRelease(session: URLSession = .shared) async throws -> GitHubRelease {
        var request = URLRequest(url: UpdateConfig.latestReleaseURL)
        request.setValue(UpdateConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.decodeFailed
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw ClientError.notFound
        default:
            throw ClientError.badResponse(http.statusCode)
        }

        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            throw ClientError.decodeFailed
        }
        if release.prerelease {
            throw ClientError.noStableRelease
        }
        guard release.version != nil else {
            throw ClientError.invalidVersion
        }
        guard release.updateAsset != nil else {
            throw ClientError.missingAsset
        }
        return release
    }
}
