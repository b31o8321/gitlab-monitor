import Foundation
import SwiftUI

struct RepositoryState: Identifiable {
    let repository: Repository
    var status: PipelineStatus
    var resolvedBranch: String?
    var webUrl: String?
    var updatedAt: Date?
    var startedAt: Date?
    var baselineDuration: TimeInterval?
    var errorMessage: String?

    var id: UUID { repository.id }
}

@MainActor
class RepositoryStore: ObservableObject {
    @Published var states: [RepositoryState] = []
    @Published var settings: AppSettings = .load()
    @Published var globalError: String? = nil

    init() {
        syncStates()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settings.save()
        syncStates()
    }

    func applyResult(_ result: PipelineResult, resolvedBranch: String, baselineDuration: TimeInterval?, for repositoryId: UUID) {
        guard let index = states.firstIndex(where: { $0.id == repositoryId }) else { return }
        states[index].status = result.status
        states[index].webUrl = result.webUrl
        states[index].updatedAt = result.updatedAt
        states[index].startedAt = result.startedAt
        states[index].baselineDuration = baselineDuration
        states[index].resolvedBranch = resolvedBranch
        states[index].errorMessage = nil
        globalError = nil
        NotificationCenter.default.post(name: .repositoryStateDidChange, object: nil)
    }

    func applyError(_ error: GitLabError, for repositoryId: UUID, resolvedBranch: String? = nil) {
        guard let index = states.firstIndex(where: { $0.id == repositoryId }) else { return }
        states[index].status = .unknown
        states[index].errorMessage = errorMessage(for: error)
        if let resolvedBranch {
            states[index].resolvedBranch = resolvedBranch
        }
        if case .unauthorized = error {
            globalError = "Token 无效，请检查设置"
        }
        NotificationCenter.default.post(name: .repositoryStateDidChange, object: nil)
    }

    var overallStatus: PipelineStatus {
        if states.isEmpty { return .unknown }
        if states.contains(where: { $0.status == .failed }) { return .failed }
        if states.contains(where: { $0.status == .running || $0.status == .pending }) { return .running }
        if states.allSatisfy({ $0.status == .success }) { return .success }
        return .unknown
    }

    private func syncStates() {
        let existing = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0) })
        states = settings.repositories.map { repo in
            existing[repo.id] ?? RepositoryState(repository: repo, status: .unknown)
        }
    }

    private func errorMessage(for error: GitLabError) -> String {
        switch error {
        case .unauthorized: return "Token 无效"
        case .notFound: return "项目未找到"
        case .networkError: return "连接失败"
        case .invalidResponse: return "响应异常"
        case .noBranchMatch: return "未匹配到分支"
        }
    }
}

extension Notification.Name {
    static let repositoryStateDidChange = Notification.Name("repositoryStateDidChange")
}
