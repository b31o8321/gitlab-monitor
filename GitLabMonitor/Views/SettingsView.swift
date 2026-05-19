import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 1
    @State private var gitlabUrl: String = ""
    @State private var token: String = ""
    @State private var pollInterval: String = "60"
    @State private var selectedRepos: [Repository] = []

    private var service: GitLabServiceProtocol { GitLabService() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .frame(width: 460, height: 560)
        .onAppear { loadCurrentSettings() }
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

                Section {
                    UpdateCheckRow()
                } header: {
                    Text("应用更新")
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
        var cleanUrl = gitlabUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") { cleanUrl = String(cleanUrl.dropLast()) }
        settings.gitlabUrl = cleanUrl
        settings.pollInterval = max(10, Int(pollInterval) ?? 60)
        store.updateSettings(settings)
        KeychainService.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func saveAndDismiss() {
        saveConnectionSettings()
        var settings = store.settings
        settings.repositories = selectedRepos
        store.updateSettings(settings)
        dismiss()
    }
}

private struct UpdateCheckRow: View {
    @ObservedObject var updates: UpdateManager = .shared

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("当前版本：v\(currentVersion)")
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: checkNow) {
                    if case .checking = updates.state {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Text("检查更新")
                    }
                }
                .disabled(isBusy)
            }
            statusLine
        }
    }

    private var isBusy: Bool {
        switch updates.state {
        case .checking, .downloading: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch updates.state {
        case .updateAvailable(let info):
            Text("发现新版本 v\(info.version)（点击菜单栏弹窗顶部的「更新」按钮安装）")
                .font(.caption2)
                .foregroundColor(.accentColor)
        case .upToDate:
            if let date = updates.lastCheck {
                Text("已是最新版（\(relativeFormatter.localizedString(for: date, relativeTo: Date()))检查）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("已是最新版")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .downloading:
            Text("正在下载更新…")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .error(let msg):
            Text("检查失败：\(msg)")
                .font(.caption2)
                .foregroundColor(.red)
                .lineLimit(2)
        default:
            EmptyView()
        }
    }

    private var relativeFormatter: RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }

    private func checkNow() {
        Task { await updates.checkForUpdate(silent: false) }
    }
}
