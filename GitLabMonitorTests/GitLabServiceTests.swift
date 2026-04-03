import XCTest
@testable import GitLabMonitor

final class GitLabServiceTests: XCTestCase {

    struct MockGitLabService: GitLabServiceProtocol {
        let resultToReturn: Result<PipelineResult, GitLabError>

        func fetchLatestPipeline(
            gitlabUrl: String,
            projectPath: String,
            branch: String,
            token: String
        ) async throws -> PipelineResult {
            switch resultToReturn {
            case .success(let result): return result
            case .failure(let error): throw error
            }
        }
    }

    func testParseSuccessPipeline() async throws {
        let expectedResult = PipelineResult(
            status: .success,
            webUrl: "https://gitlab.example.com/group/project/-/pipelines/1",
            updatedAt: Date()
        )
        let mock = MockGitLabService(resultToReturn: .success(expectedResult))
        let result = try await mock.fetchLatestPipeline(
            gitlabUrl: "https://gitlab.example.com",
            projectPath: "group/project",
            branch: "main",
            token: "test-token"
        )
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.webUrl, "https://gitlab.example.com/group/project/-/pipelines/1")
    }

    func testParseRunningPipeline() async throws {
        let expectedResult = PipelineResult(
            status: .running,
            webUrl: "https://gitlab.example.com/group/project/-/pipelines/2",
            updatedAt: Date()
        )
        let mock = MockGitLabService(resultToReturn: .success(expectedResult))
        let result = try await mock.fetchLatestPipeline(
            gitlabUrl: "https://gitlab.example.com",
            projectPath: "group/project",
            branch: "main",
            token: "test-token"
        )
        XCTAssertEqual(result.status, .running)
    }

    func testUnauthorizedThrows() async {
        let mock = MockGitLabService(resultToReturn: .failure(.unauthorized))
        do {
            _ = try await mock.fetchLatestPipeline(
                gitlabUrl: "https://gitlab.example.com",
                projectPath: "group/project",
                branch: "main",
                token: "bad-token"
            )
            XCTFail("Expected GitLabError.unauthorized")
        } catch GitLabError.unauthorized {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotFoundThrows() async {
        let mock = MockGitLabService(resultToReturn: .failure(.notFound))
        do {
            _ = try await mock.fetchLatestPipeline(
                gitlabUrl: "https://gitlab.example.com",
                projectPath: "group/project",
                branch: "main",
                token: "test-token"
            )
            XCTFail("Expected GitLabError.notFound")
        } catch GitLabError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
