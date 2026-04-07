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
                            repoRow(
                                projectId: project?.id,
                                pathWithNamespace: repo.projectPath,
                                name: repo.name,
                                selectedBranch: repo.branch,
                                isSelected: true
                            )
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
                            repoRow(
                                projectId: project.id,
                                pathWithNamespace: project.pathWithNamespace,
                                name: project.name,
                                selectedBranch: nil,
                                isSelected: false
                            )
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

    @ViewBuilder
    private func repoRow(
        projectId: Int?,
        pathWithNamespace: String,
        name: String,
        selectedBranch: String?,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(name).fontWeight(.medium)
                Text(pathWithNamespace).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if isSelected, let id = projectId {
                branchPicker(projectId: id, pathWithNamespace: pathWithNamespace, currentBranch: selectedBranch ?? "main")
            } else if isSelected {
                branchPicker(projectId: nil, pathWithNamespace: pathWithNamespace, currentBranch: selectedBranch ?? "main")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(projectId: projectId, pathWithNamespace: pathWithNamespace, name: name)
        }
    }

    @ViewBuilder
    private func branchPicker(projectId: Int?, pathWithNamespace: String, currentBranch: String) -> some View {
        let load = projectId.flatMap { branchState[$0] }
        let branches = load?.branches ?? []

        Group {
            if let pid = projectId, load == nil {
                // Trigger load on appear
                Text(currentBranch)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .onAppear { loadBranches(projectId: pid) }
            } else if load?.loading == true {
                ProgressView().scaleEffect(0.5).frame(width: 60)
            } else if load?.failed == true {
                TextField("分支", text: branchBinding(pathWithNamespace: pathWithNamespace, currentBranch: currentBranch))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .font(.caption)
            } else if branches.isEmpty {
                TextField("分支", text: branchBinding(pathWithNamespace: pathWithNamespace, currentBranch: currentBranch))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .font(.caption)
            } else {
                Picker("", selection: branchBinding(pathWithNamespace: pathWithNamespace, currentBranch: currentBranch)) {
                    ForEach(branches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
                .font(.caption)
            }
        }
    }

    private func branchBinding(pathWithNamespace: String, currentBranch: String) -> Binding<String> {
        Binding(
            get: {
                selectedRepos.first { $0.projectPath == pathWithNamespace }?.branch ?? currentBranch
            },
            set: { newBranch in
                if let idx = selectedRepos.firstIndex(where: { $0.projectPath == pathWithNamespace }) {
                    selectedRepos[idx] = Repository(
                        id: selectedRepos[idx].id,
                        name: selectedRepos[idx].name,
                        projectPath: selectedRepos[idx].projectPath,
                        branch: newBranch
                    )
                }
            }
        )
    }

    private func toggleSelection(projectId: Int?, pathWithNamespace: String, name: String) {
        if let idx = selectedRepos.firstIndex(where: { $0.projectPath == pathWithNamespace }) {
            selectedRepos.remove(at: idx)
        } else {
            // Determine default branch
            let defaultBranch: String
            if let pid = projectId, let branches = branchState[pid]?.branches, let first = branches.first {
                defaultBranch = first
            } else if let project = searchResults.first(where: { $0.id == projectId }) {
                defaultBranch = project.defaultBranch ?? "main"
            } else {
                defaultBranch = "main"
            }
            let repo = Repository(name: name, projectPath: pathWithNamespace, branch: defaultBranch)
            selectedRepos.append(repo)
            if let pid = projectId, branchState[pid] == nil {
                loadBranches(projectId: pid)
            }
        }
    }

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
                    errorMessage = e.localizedDescription
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
                    // If selected, update to first branch if not already set to a valid one
                    if let idx = selectedRepos.firstIndex(where: {
                        searchResults.first(where: { $0.id == projectId })?.pathWithNamespace == $0.projectPath
                    }) {
                        let currentBranch = selectedRepos[idx].branch
                        if !names.contains(currentBranch), let first = names.first {
                            selectedRepos[idx] = Repository(
                                id: selectedRepos[idx].id,
                                name: selectedRepos[idx].name,
                                projectPath: selectedRepos[idx].projectPath,
                                branch: first
                            )
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    branchState[projectId] = BranchLoad(failed: true)
                }
            }
        }
    }
}
