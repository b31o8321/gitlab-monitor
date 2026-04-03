import XCTest
@testable import GitLabMonitor

@MainActor
final class PipelinePollerTests: XCTestCase {

    struct MockGitLabService: GitLabServiceProtocol {
        var result: Result<PipelineResult, GitLabError>

        func fetchLatestPipeline(
            gitlabUrl: String,
            projectPath: String,
            branch: String,
            token: String
        ) async throws -> PipelineResult {
            switch result {
            case .success(let r): return r
            case .failure(let e): throw e
            }
        }

        func fetchProjects(gitlabUrl: String, token: String, search: String) async throws -> [GitLabProject] {
            return []
        }

        func fetchBranches(gitlabUrl: String, token: String, projectId: Int) async throws -> [GitLabBranch] {
            return []
        }
    }

    func testPollerUpdatesStoreOnSuccess() async throws {
        let store = RepositoryStore()
        let repo = Repository(name: "test", projectPath: "group/project", branch: "main")
        var settings = AppSettings.default
        settings.gitlabUrl = "https://gitlab.example.com"
        settings.repositories = [repo]
        store.updateSettings(settings)

        let mockResult = PipelineResult(
            status: .success,
            webUrl: "https://gitlab.example.com/group/project/-/pipelines/1",
            updatedAt: Date()
        )
        let mockService = MockGitLabService(result: .success(mockResult))
        let poller = PipelinePoller(store: store, service: mockService)

        await poller.pollOnce(token: "test-token")

        XCTAssertEqual(store.states.first?.status, .success)
        XCTAssertNil(store.states.first?.errorMessage)
    }

    func testPollerUpdatesStoreOnError() async throws {
        let store = RepositoryStore()
        let repo = Repository(name: "test", projectPath: "group/project", branch: "main")
        var settings = AppSettings.default
        settings.gitlabUrl = "https://gitlab.example.com"
        settings.repositories = [repo]
        store.updateSettings(settings)

        let mockService = MockGitLabService(result: .failure(.notFound))
        let poller = PipelinePoller(store: store, service: mockService)

        await poller.pollOnce(token: "test-token")

        XCTAssertEqual(store.states.first?.status, .unknown)
        XCTAssertEqual(store.states.first?.errorMessage, "项目未找到")
    }
}
