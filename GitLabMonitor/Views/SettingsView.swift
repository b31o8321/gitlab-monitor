import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    @Environment(\.dismiss) var dismiss

    @State private var gitlabUrl: String = ""
    @State private var token: String = ""
    @State private var pollInterval: String = "60"
    @State private var showAddRepo = false
    @State private var editingRepo: Repository? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("完成") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

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
                            if let url = URL(string: "\(baseUrl)/-/user_settings/personal_access_tokens") {
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

                Section {
                    ForEach(store.settings.repositories) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.name).fontWeight(.medium)
                                Text("\(repo.projectPath) @ \(repo.branch)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("编辑") { editingRepo = repo }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            Button("删除") { deleteRepo(repo) }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 2)
                    }
                    Button("+ 添加仓库") { showAddRepo = true }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                } header: {
                    Text("仓库列表")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 520)
        .onAppear { loadCurrentSettings() }
        .sheet(isPresented: $showAddRepo) {
            RepoFormView(existingRepo: nil) { newRepo in
                var settings = store.settings
                settings.repositories.append(newRepo)
                store.updateSettings(settings)
            }
        }
        .sheet(item: $editingRepo) { repo in
            RepoFormView(existingRepo: repo) { updated in
                var settings = store.settings
                if let idx = settings.repositories.firstIndex(where: { $0.id == updated.id }) {
                    settings.repositories[idx] = updated
                }
                store.updateSettings(settings)
            }
        }
    }

    private func loadCurrentSettings() {
        gitlabUrl = store.settings.gitlabUrl
        token = KeychainService.loadToken() ?? ""
        pollInterval = "\(store.settings.pollInterval)"
    }

    private func saveAndDismiss() {
        var settings = store.settings
        settings.gitlabUrl = gitlabUrl
        settings.pollInterval = Int(pollInterval) ?? 60
        store.updateSettings(settings)
        KeychainService.saveToken(token)
        dismiss()
    }

    private func deleteRepo(_ repo: Repository) {
        var settings = store.settings
        settings.repositories.removeAll { $0.id == repo.id }
        store.updateSettings(settings)
    }
}

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
