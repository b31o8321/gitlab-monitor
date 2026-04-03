import Foundation

struct GitLabService: GitLabServiceProtocol {

    private struct PipelineJSON: Decodable {
        let status: String
        let web_url: String
        let updated_at: String
    }

    func fetchLatestPipeline(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String
    ) async throws -> PipelineResult {
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
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

        let formatter = ISO8601DateFormatter()
        let updatedAt = formatter.date(from: first.updated_at) ?? Date()

        return PipelineResult(
            status: PipelineStatus(rawValue: first.status) ?? .unknown,
            webUrl: first.web_url,
            updatedAt: updatedAt
        )
    }
}
