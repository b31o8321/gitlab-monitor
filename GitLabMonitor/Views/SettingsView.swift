import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 1
    @State private var gitlabUrl: String = ""
    @State private var token: String = ""
    @State private var pollInterval: String = "60"
    @State private var selectedRepos: [Repository] = []
    @State private var editingRepo: Repository? = nil

    private var service: GitLabServiceProtocol { GitLabService() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(step == 1 ? "连接设置" : "监控仓库")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                if step == 2 {
                    Text("已选\(selectedRepos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                Text("\(step)/2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
            .padding()

            Divider()

            if step == 1 {
                step1View
            } else {
                step2View
            }
        }
        .frame(width: 420, height: 480)
        .onAppear { loadCurrentSettings() }
        .sheet(item: $editingRepo) { repo in
            RepoFormView(existingRepo: repo) { updated in
                if let idx = selectedRepos.firstIndex(where: { $0.id == updated.id }) {
                    selectedRepos[idx] = updated
                }
            }
        }
    }

    // MARK: - Step 1

    private var step1View: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("https://gitlab.company.com", text: $gitlabUrl)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("GitLab 地址")
                }

                Section {
                    SecureField("glpat-xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("需要 read_api 权限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("?") {
                            let baseUrl = gitlabUrl.isEmpty ? "https://gitlab.com" : gitlabUrl
                            if let url = URL(string: "\(baseUrl)/-/profile/personal_access_tokens") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                } header: {
                    Text("Access Token")
                }

                Section {
                    HStack {
                        TextField("60", text: $pollInterval)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("秒")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("轮询间隔")
                }
            }
            .formStyle(.grouped)

            Spacer()

            HStack {
                Spacer()
                Button("下一步 →") { goToStep2() }
                    .buttonStyle(.borderedProminent)
                    .disabled(gitlabUrl.isEmpty || token.isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Step 2

    private var step2View: some View {
        VStack(spacing: 0) {
            ProjectSearchView(
                gitlabUrl: gitlabUrl,
                token: token,
                service: service,
                selectedRepos: $selectedRepos
            )

            Divider()

            HStack {
                Button("← 返回") { step = 1 }
                    .buttonStyle(.plain)
                Spacer()
                Button("完成") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadCurrentSettings() {
        gitlabUrl = store.settings.gitlabUrl
        token = KeychainService.loadToken() ?? ""
        pollInterval = "\(store.settings.pollInterval)"
        selectedRepos = store.settings.repositories
    }

    private func goToStep2() {
        saveConnectionSettings()
        step = 2
    }

    private func saveConnectionSettings() {
        var settings = store.settings
        settings.gitlabUrl = gitlabUrl
        settings.pollInterval = max(10, Int(pollInterval) ?? 60)
        store.updateSettings(settings)
        KeychainService.saveToken(token)
    }

    private func saveAndDismiss() {
        saveConnectionSettings()
        var settings = store.settings
        // Merge: keep existing repos not in selectedRepos, then add all selected
        // Simpler: replace entirely with selectedRepos (user has full control in step 2)
        settings.repositories = selectedRepos
        store.updateSettings(settings)
        dismiss()
    }
}

// MARK: - RepoFormView (used only for editing existing repos)

struct RepoFormView: View {
    let existingRepo: Repository?
    let onSave: (Repository) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var projectPath: String = ""
    @State private var branch: String = "main"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(existingRepo == nil ? "添加仓库" : "编辑仓库")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.plain)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || projectPath.isEmpty || branch.isEmpty)
            }
            .padding()
            Divider()
            Form {
                TextField("前端服务", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("group/project", text: $projectPath)
                    .textFieldStyle(.roundedBorder)
                TextField("main", text: $branch)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 280)
        .onAppear {
            if let repo = existingRepo {
                name = repo.name
                projectPath = repo.projectPath
                branch = repo.branch
            }
        }
    }

    private func save() {
        let repo = Repository(
            id: existingRepo?.id ?? UUID(),
            name: name,
            projectPath: projectPath,
            branch: branch
        )
        onSave(repo)
        dismiss()
    }
}
