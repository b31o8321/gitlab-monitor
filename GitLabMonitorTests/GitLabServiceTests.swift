import XCTest
@testable import GitLabMonitor

final class GitLabServiceTests: XCTestCase {

    struct MockGitLabService: GitLabServiceProtocol {
        let responseJSON: String
        let statusCode: Int

        func fetchLatestPipeline(
            gitlabUrl: String,
            projectPath: String,
            branch: String,
            token: String
        ) async throws -> PipelineResult {
            if statusCode == 401 { throw GitLabError.unauthorized }
            if statusCode == 404 { throw GitLabError.notFound }

            let data = Data(responseJSON.utf8)
            let pipelines = try JSONDecoder().decode([PipelineJSON].self, from: data)
            guard let first = pipelines.first else { throw GitLabError.invalidResponse }
            return PipelineResult(
                status: PipelineStatus(rawValue: first.status) ?? .unknown,
                webUrl: first.web_url,
                updatedAt: ISO8601DateFormatter().date(from: first.updated_at) ?? Date()
            )
        }
    }

    private struct PipelineJSON: Decodable {
        let status: String
        let web_url: String
        let updated_at: String
    }

    func testParseSuccessPipeline() async throws {
        let json = """
        [{"status":"success","web_url":"https://gitlab.example.com/group/project/-/pipelines/1","updated_at":"2026-04-03T10:00:00Z"}]
        """
        let mock = MockGitLabService(responseJSON: json, statusCode: 200)
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
        let json = """
        [{"status":"running","web_url":"https://gitlab.example.com/group/project/-/pipelines/2","updated_at":"2026-04-03T10:01:00Z"}]
        """
        let mock = MockGitLabService(responseJSON: json, statusCode: 200)
        let result = try await mock.fetchLatestPipeline(
            gitlabUrl: "https://gitlab.example.com",
            projectPath: "group/project",
            branch: "main",
            token: "test-token"
        )
        XCTAssertEqual(result.status, .running)
    }

    func testUnauthorizedThrows() async {
        let mock = MockGitLabService(responseJSON: "[]", statusCode: 401)
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
        let mock = MockGitLabService(responseJSON: "[]", statusCode: 404)
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
