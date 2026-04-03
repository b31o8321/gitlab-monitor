import Foundation

struct PipelineResult {
    let status: PipelineStatus
    let webUrl: String
    let updatedAt: Date
}

protocol GitLabServiceProtocol {
    func fetchLatestPipeline(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String
    ) async throws -> PipelineResult
}

enum GitLabError: Error {
    case unauthorized
    case notFound
    case networkError(Error)
    case invalidResponse
}
