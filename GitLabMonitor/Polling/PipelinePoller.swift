import Foundation

@MainActor
class PipelinePoller {
    private let store: RepositoryStore
    private let service: GitLabServiceProtocol
    private let resolver: BranchResolver
    private var timer: Timer?
    private var isPolling = false

    init(store: RepositoryStore, service: GitLabServiceProtocol = GitLabService()) {
        self.store = store
        self.service = service
        self.resolver = BranchResolver(service: service)
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

    func pollOnce(token: String, manual: Bool = false) async {
        if isPolling && !manual { return }
        isPolling = true
        defer { isPolling = false }

        let settings = store.settings
        await withTaskGroup(of: Void.self) { group in
            for repo in settings.repositories {
                group.addTask { @MainActor in
                    await self.pollRepository(repo, gitlabUrl: settings.gitlabUrl, token: token)
                }
            }
        }
    }

    private func pollRepository(_ repo: Repository, gitlabUrl: String, token: String) async {
        let resolvedBranch: String?
        do {
            resolvedBranch = try await resolver.resolve(
                selector: repo.branchSelector,
                gitlabUrl: gitlabUrl,
                projectPath: repo.projectPath,
                token: token
            )
        } catch let error as GitLabError {
            store.applyError(error, for: repo.id)
            return
        } catch {
            store.applyError(.networkError(error), for: repo.id)
            return
        }

        guard let branch = resolvedBranch else {
            store.applyError(.noBranchMatch, for: repo.id)
            return
        }

        do {
            let result = try await service.fetchLatestPipeline(
                gitlabUrl: gitlabUrl,
                projectPath: repo.projectPath,
                branch: branch,
                token: token
            )
            store.applyResult(result, resolvedBranch: branch, for: repo.id)
        } catch let error as GitLabError {
            store.applyError(error, for: repo.id, resolvedBranch: branch)
        } catch {
            store.applyError(.networkError(error), for: repo.id, resolvedBranch: branch)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
