import Foundation

struct UpdateInfo: Equatable {
    let version: String
    let releaseUrl: String
    let dmgUrl: URL?
    let releaseNotes: String?
}

struct UpdateChecker {
    let repo: String

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
        let prerelease: Bool
        let draft: Bool
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }

    func checkLatest() async throws -> UpdateInfo? {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.prerelease, !release.draft else { return nil }

        let latest = Self.stripV(release.tag_name)
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        guard Self.compareSemver(latest, current) > 0 else { return nil }

        let dmgUrl = release.assets
            .first(where: { $0.name.lowercased().hasSuffix(".dmg") })
            .flatMap { URL(string: $0.browser_download_url) }
        return UpdateInfo(
            version: latest,
            releaseUrl: release.html_url,
            dmgUrl: dmgUrl,
            releaseNotes: release.body
        )
    }

    static func stripV(_ s: String) -> String {
        s.hasPrefix("v") ? String(s.dropFirst()) : s
    }

    /// Lexicographic semver compare (dot-separated ints). Returns -1 / 0 / 1.
    /// Pre-release suffixes are ignored beyond the numeric prefix.
    static func compareSemver(_ a: String, _ b: String) -> Int {
        let ap = numericParts(a)
        let bp = numericParts(b)
        let n = max(ap.count, bp.count)
        for i in 0..<n {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av != bv { return av < bv ? -1 : 1 }
        }
        return 0
    }

    private static func numericParts(_ s: String) -> [Int] {
        s.split(separator: ".").compactMap { part -> Int? in
            // strip non-digits (e.g., "1-beta" → "1")
            let digits = part.prefix { $0.isNumber }
            return Int(digits)
        }
    }
}
