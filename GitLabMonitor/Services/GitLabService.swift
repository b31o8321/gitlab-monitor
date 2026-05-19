import Foundation

struct GitLabService: GitLabServiceProtocol {

    private struct PipelineJSON: Decodable {
        let status: String
        let web_url: String
        let updated_at: String
        let created_at: String?
        let started_at: String?
        let finished_at: String?
        let duration: Int?
    }

    private struct ProjectJSON: Decodable {
        let id: Int
        let name: String
        let path_with_namespace: String
        let default_branch: String?
    }

    private struct BranchJSON: Decodable {
        let name: String
    }

    func fetchLatestPipeline(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String
    ) async throws -> PipelineResult {
        // Slash must be encoded as %2F for GitLab project path API segment
        var pathAllowedMinusSlash = CharacterSet.urlPathAllowed
        pathAllowedMinusSlash.remove("/")
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: pathAllowedMinusSlash) ?? projectPath
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? branch
        let urlString = "\(gitlabUrl)/api/v4/projects/\(encodedPath)/pipelines?ref=\(encodedBranch)&per_page=1&order_by=id&sort=desc"
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitLabError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitLabError.invalidResponse }
        if http.statusCode == 401 { throw GitLabError.unauthorized }
        if http.statusCode == 404 { throw GitLabError.notFound }

        let pipelines = try JSONDecoder().decode([PipelineJSON].self, from: data)
        guard let first = pipelines.first else { throw GitLabError.invalidResponse }

        let updatedAt = Self.parseGitLabDate(first.updated_at) ?? Date()
        // Prefer started_at (actual execution start); fall back to created_at;
        // for running pipelines on list endpoints that only return updated_at,
        // fall back further so we can still show a useful "elapsed" indicator.
        let startedAt: Date? = Self.parseGitLabDate(first.started_at)
            ?? Self.parseGitLabDate(first.created_at)
            ?? Self.parseGitLabDate(first.updated_at)

        return PipelineResult(
            status: PipelineStatus(rawValue: first.status) ?? .unknown,
            webUrl: first.web_url,
            updatedAt: updatedAt,
            startedAt: startedAt
        )
    }

    /// GitLab returns timestamps either with or without fractional seconds depending
    /// on version and endpoint, so try the strict ISO8601 parser both ways.
    private static func parseGitLabDate(_ str: String?) -> Date? {
        guard let str = str, !str.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: str) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: str)
    }

    func fetchRecentSuccessDurations(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String,
        limit: Int
    ) async throws -> [TimeInterval] {
        var pathAllowedMinusSlash = CharacterSet.urlPathAllowed
        pathAllowedMinusSlash.remove("/")
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: pathAllowedMinusSlash) ?? projectPath
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? branch
        let per = max(1, min(limit, 20))
        let urlString = "\(gitlabUrl)/api/v4/projects/\(encodedPath)/pipelines?ref=\(encodedBranch)&status=success&per_page=\(per)&order_by=id&sort=desc"
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitLabError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitLabError.invalidResponse }
        if http.statusCode == 401 { throw GitLabError.unauthorized }
        if http.statusCode == 404 { throw GitLabError.notFound }

        let pipelines = try JSONDecoder().decode([PipelineJSON].self, from: data)

        return pipelines.compactMap { p -> TimeInterval? in
            // Prefer the API-provided duration field when present.
            if let d = p.duration, d > 0 { return TimeInterval(d) }
            // Fall back to (finished|updated)_at − (started|created)_at.
            guard let end = Self.parseGitLabDate(p.finished_at) ?? Self.parseGitLabDate(p.updated_at) else { return nil }
            guard let start = Self.parseGitLabDate(p.started_at) ?? Self.parseGitLabDate(p.created_at) else { return nil }
            let interval = end.timeIntervalSince(start)
            return interval > 0 ? interval : nil
        }
    }

    func fetchProjects(gitlabUrl: String, token: String, search: String) async throws -> [GitLabProject] {
        let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
        let urlString = "\(gitlabUrl)/api/v4/projects?membership=true&order_by=last_activity_at&sort=desc&per_page=5&search=\(encodedSearch)"
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitLabError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitLabError.invalidResponse }
        if http.statusCode == 401 { throw GitLabError.unauthorized }
        if http.statusCode == 404 { throw GitLabError.notFound }

        let projects = try JSONDecoder().decode([ProjectJSON].self, from: data)
        return projects.map {
            GitLabProject(id: $0.id, name: $0.name, pathWithNamespace: $0.path_with_namespace, defaultBranch: $0.default_branch)
        }
    }

    func fetchBranches(gitlabUrl: String, token: String, projectId: Int) async throws -> [GitLabBranch] {
        let urlString = "\(gitlabUrl)/api/v4/projects/\(projectId)/repository/branches?per_page=100"
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }
        return try await loadBranches(url: url, token: token)
    }

    func fetchBranches(gitlabUrl: String, token: String, projectPath: String, search: String?) async throws -> [GitLabBranch] {
        var pathAllowedMinusSlash = CharacterSet.urlPathAllowed
        pathAllowedMinusSlash.remove("/")
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: pathAllowedMinusSlash) ?? projectPath

        var urlString = "\(gitlabUrl)/api/v4/projects/\(encodedPath)/repository/branches?per_page=100"
        if let search = search, !search.isEmpty {
            let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            urlString += "&search=\(encodedSearch)"
        }
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }
        return try await loadBranches(url: url, token: token)
    }

    private func loadBranches(url: URL, token: String) async throws -> [GitLabBranch] {
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitLabError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitLabError.invalidResponse }
        if http.statusCode == 401 { throw GitLabError.unauthorized }
        if http.statusCode == 404 { throw GitLabError.notFound }

        let branches = try JSONDecoder().decode([BranchJSON].self, from: data)
        return branches.map { GitLabBranch(name: $0.name) }
    }
}
