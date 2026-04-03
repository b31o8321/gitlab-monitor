import Foundation

@MainActor
class PipelinePoller {
    private let store: RepositoryStore
    private let service: GitLabServiceProtocol
    private var timer: Timer?

    init(store: RepositoryStore, service: GitLabServiceProtocol = GitLabService()) {
        self.store = store
        self.service = service
    }

    func start() {
        stopTimer()
        let interval = TimeInterval(store.settings.pollInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollOnce(token: KeychainService.loadToken() ?? "")
            }
        }
        // poll immediately on start
        Task { @MainActor in
            await pollOnce(token: KeychainService.loadToken() ?? "")
        }
    }

    func stop() {
        stopTimer()
    }

    func pollOnce(token: String) async {
        let settings = store.settings
        await withTaskGroup(of: Void.self) { group in
            for repo in settings.repositories {
                group.addTask { @MainActor in
                    do {
                        let result = try await self.service.fetchLatestPipeline(
                            gitlabUrl: settings.gitlabUrl,
                            projectPath: repo.projectPath,
                            branch: repo.branch,
                            token: token
                        )
                        self.store.applyResult(result, for: repo.id)
                    } catch let error as GitLabError {
                        self.store.applyError(error, for: repo.id)
                    } catch {
                        self.store.applyError(.networkError(error), for: repo.id)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
