import SwiftUI

struct ProjectSearchView: View {
    let gitlabUrl: String
    let token: String
    let service: GitLabServiceProtocol
    @Binding var selectedRepos: [Repository]

    @State private var searchText: String = ""
    @State private var searchResults: [GitLabProject] = []
    @State private var loadingState: LoadState = .idle
    @State private var errorMessage: String = ""
    @State private var branchState: [Int: BranchLoad] = [:]
    @State private var searchTask: Task<Void, Never>?

    enum LoadState {
        case idle, loading, loaded, failed
    }

    private var normalizedUrl: String {
        gitlabUrl.hasSuffix("/") ? String(gitlabUrl.dropLast()) : gitlabUrl
    }

    struct BranchLoad {
        var branches: [String] = []
        var loading: Bool = false
        var failed: Bool = false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索仓库名称...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Already-selected repos always shown at top
                    if !selectedRepos.isEmpty {
                        sectionHeader("已选择")
                        ForEach(selectedRepos) { repo in
                            let project = searchResults.first { $0.pathWithNamespace == repo.projectPath }
                            selectedRepoCard(repo: repo, projectId: project?.id)
                            Divider().padding(.leading, 40)
                        }
                    }

                    // Search results (excluding already-selected)
                    let unselected = searchResults.filter { p in
                        !selectedRepos.contains { $0.projectPath == p.pathWithNamespace }
                    }
                    if !searchResults.isEmpty || loadingState == .loading {
                        sectionHeader("搜索结果")
                    }
                    switch loadingState {
                    case .loading:
                        HStack {
                            ProgressView().scaleEffect(0.7)
                            Text("加载中...").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                    case .failed:
                        VStack(alignment: .leading, spacing: 4) {
                            Text("加载失败")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            Button("重试") { loadProjects() }
                                .font(.caption)
                        }
                        .padding()
                    case .loaded where searchResults.isEmpty:
                        Text("未找到相关仓库")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    case .loaded:
                        ForEach(unselected) { project in
                            unselectedRepoRow(project: project)
                            Divider().padding(.leading, 40)
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .onAppear { loadProjects() }
        .onChange(of: searchText) { _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                loadProjects()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    // MARK: - Unselected (single line, no expanded controls)

    @ViewBuilder
    private func unselectedRepoRow(project: GitLabProject) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square")
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).fontWeight(.medium)
                Text(project.pathWithNamespace).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(projectId: project.id, pathWithNamespace: project.pathWithNamespace, name: project.name, defaultBranch: project.defaultBranch)
        }
    }

    // MARK: - Selected (with branch mode picker)

    @ViewBuilder
    private func selectedRepoCard(repo: Repository, projectId: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name).fontWeight(.medium)
                    Text(repo.projectPath).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if let idx = selectedRepos.firstIndex(where: { $0.id == repo.id }) {
                        selectedRepos.remove(at: idx)
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            BranchSelectorEditor(
                repo: repo,
                projectId: projectId,
                branchState: branchState[projectId ?? -1],
                onSelectorChange: { newSelector in
                    if let idx = selectedRepos.firstIndex(where: { $0.id == repo.id }) {
                        selectedRepos[idx].branchSelector = newSelector
                    }
                },
                onLoadBranches: {
                    if let pid = projectId, branchState[pid] == nil {
                        loadBranches(projectId: pid)
                    }
                }
            )
            .padding(.leading, 30)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Selection state

    private func toggleSelection(projectId: Int?, pathWithNamespace: String, name: String, defaultBranch: String?) {
        if let idx = selectedRepos.firstIndex(where: { $0.projectPath == pathWithNamespace }) {
            selectedRepos.remove(at: idx)
        } else {
            let initialBranch = defaultBranch ?? "main"
            let repo = Repository(name: name, projectPath: pathWithNamespace, branchSelector: .fixed(initialBranch))
            selectedRepos.append(repo)
            if let pid = projectId, branchState[pid] == nil {
                loadBranches(projectId: pid)
            }
        }
    }

    // MARK: - Loaders

    private func loadProjects() {
        loadingState = .loading
        errorMessage = ""
        Task {
            do {
                let projects = try await service.fetchProjects(
                    gitlabUrl: normalizedUrl,
                    token: token,
                    search: searchText
                )
                await MainActor.run {
                    searchResults = projects
                    loadingState = .loaded
                }
            } catch let e as GitLabError {
                await MainActor.run {
                    errorMessage = e.errorDescription ?? "\(e)"
                    loadingState = .failed
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    loadingState = .failed
                }
            }
        }
    }

    private func loadBranches(projectId: Int) {
        branchState[projectId] = BranchLoad(loading: true)
        Task {
            do {
                let branches = try await service.fetchBranches(
                    gitlabUrl: normalizedUrl,
                    token: token,
                    projectId: projectId
                )
                let names = branches.map { $0.name }
                await MainActor.run {
                    branchState[projectId] = BranchLoad(branches: names, loading: false, failed: false)
                }
            } catch {
                await MainActor.run {
                    branchState[projectId] = BranchLoad(failed: true)
                }
            }
        }
    }
}

// MARK: - BranchSelectorEditor

private struct BranchSelectorEditor: View {
    let repo: Repository
    let projectId: Int?
    let branchState: ProjectSearchView.BranchLoad?
    let onSelectorChange: (BranchSelector) -> Void
    let onLoadBranches: () -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case fixed = "固定分支"
        case rule = "动态匹配最新"
        case regex = "自定义正则"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .fixed
    @State private var fixedBranch: String = "main"
    @State private var rulePrefix: String = "test"
    @State private var ruleFormat: BranchDateFormat = .yyyymmdd
    @State private var regexPattern: String = "^test-\\d{8}$"
    @State private var initialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("分支", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .fixed:
                fixedSection
            case .rule:
                ruleSection
            case .regex:
                regexSection
            }
        }
        .font(.caption)
        .onAppear { initializeFromSelector() }
        .onChange(of: mode) { _ in publishSelector() }
        .onChange(of: fixedBranch) { _ in publishSelector() }
        .onChange(of: rulePrefix) { _ in publishSelector() }
        .onChange(of: ruleFormat) { _ in publishSelector() }
        .onChange(of: regexPattern) { _ in publishSelector() }
    }

    @ViewBuilder
    private var fixedSection: some View {
        if let load = branchState, !load.branches.isEmpty {
            Picker("", selection: $fixedBranch) {
                ForEach(load.branches, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        } else if branchState?.loading == true {
            HStack { ProgressView().scaleEffect(0.5); Text("加载分支...").foregroundColor(.secondary) }
                .onAppear { onLoadBranches() }
        } else {
            TextField("分支名", text: $fixedBranch)
                .textFieldStyle(.roundedBorder)
                .onAppear { onLoadBranches() }
        }
    }

    @ViewBuilder
    private var ruleSection: some View {
        HStack {
            Text("前缀:").foregroundColor(.secondary)
            TextField("test", text: $rulePrefix)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
            Picker("", selection: $ruleFormat) {
                ForEach(BranchDateFormat.allCases, id: \.self) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .labelsHidden()
            .frame(width: 130)
        }
        Text("匹配 \(BranchDateFormat.example(prefix: rulePrefix, format: ruleFormat))")
            .foregroundColor(.secondary)
            .font(.caption2)
    }

    @ViewBuilder
    private var regexSection: some View {
        TextField("^test-\\d{8}$", text: $regexPattern)
            .textFieldStyle(.roundedBorder)
            .font(.system(.caption, design: .monospaced))
    }

    private func initializeFromSelector() {
        guard !initialized else { return }
        initialized = true
        switch repo.branchSelector {
        case .fixed(let name):
            mode = .fixed
            fixedBranch = name
        case .rule(let prefix, let format):
            mode = .rule
            rulePrefix = prefix
            ruleFormat = format
        case .regex(let pattern):
            mode = .regex
            regexPattern = pattern
        }
    }

    private func publishSelector() {
        guard initialized else { return }
        let selector: BranchSelector
        switch mode {
        case .fixed: selector = .fixed(fixedBranch)
        case .rule: selector = .rule(prefix: rulePrefix, format: ruleFormat)
        case .regex: selector = .regex(regexPattern)
        }
        if selector != repo.branchSelector {
            onSelectorChange(selector)
        }
    }
}

private extension BranchDateFormat {
    static func example(prefix: String, format: BranchDateFormat) -> String {
        let p = prefix.isEmpty ? "test" : prefix
        switch format {
        case .yyyymmdd: return "\(p)-20260326"
        case .yyyymmddDashed: return "\(p)-2026-03-26"
        case .yyyymmddDotted: return "\(p)-2026.03.26"
        case .yyyymmddWithTail: return "\(p)-20260326-hotfix"
        }
    }
}
