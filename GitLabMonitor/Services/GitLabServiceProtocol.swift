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

    func fetchProjects(
        gitlabUrl: String,
        token: String,
        search: String
    ) async throws -> [GitLabProject]

    func fetchBranches(
        gitlabUrl: String,
        token: String,
        projectId: Int
    ) async throws -> [GitLabBranch]
}

enum GitLabError: Error {
    case unauthorized
    case notFound
    case networkError(Error)
    case invalidResponse
}
