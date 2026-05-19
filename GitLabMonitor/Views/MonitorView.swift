import SwiftUI
import AppKit

extension Notification.Name {
    static let openSettings = Notification.Name("com.gitlab-monitor.openSettings")
    static let refreshRequested = Notification.Name("com.gitlab-monitor.refreshRequested")
    static let closePopoverRequested = Notification.Name("com.gitlab-monitor.closePopoverRequested")
}

struct MonitorView: View {
    @ObservedObject var store: RepositoryStore
    @ObservedObject var updates: UpdateManager = .shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("GitLab Monitor")
                    .fontWeight(.semibold)
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NotificationCenter.default.post(name: .refreshRequested, object: nil)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            updateBanner

            Divider()

            // Global error banner
            if let error = store.globalError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                Divider()
            }

            // Repository list
            if store.states.isEmpty {
                Text("暂无仓库，请在设置中添加")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.states) { state in
                            RepositoryRowView(state: state)
                                .padding(.horizontal, 12)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private var updateBanner: some View {
        switch updates.state {
        case .updateAvailable(let info):
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                Text("v\(info.version) 可用")
                    .font(.caption)
                Spacer()
                Button("更新") { promptForUpdate(info) }
                    .controlSize(.small)
                Button(action: { updates.skipCurrentVersion() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("跳过该版本")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
        case .downloading:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.5)
                Text("正在下载更新…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
        case .error(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("更新错误：\(msg)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        default:
            EmptyView()
        }
    }

    private func promptForUpdate(_ info: UpdateInfo) {
        // Close the popover before showing modal so the alert isn't dismissed by
        // the global click monitor.
        NotificationCenter.default.post(name: .closePopoverRequested, object: nil)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "GitLab Monitor v\(info.version) 可用"
        let notes = (info.releaseNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let notesPreview = notes.isEmpty
            ? "（无版本说明）"
            : (notes.count > 600 ? String(notes.prefix(600)) + "…" : notes)
        alert.informativeText = """
        当前版本：v\(appVersion) → v\(info.version)

        更新内容：
        \(notesPreview)

        点击"现在更新"会自动下载并替换应用，然后重启。
        """
        alert.addButton(withTitle: "现在更新")
        alert.addButton(withTitle: "稍后")
        alert.addButton(withTitle: "跳过该版本")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task { await updates.performUpdate() }
        case .alertSecondButtonReturn:
            updates.dismissUpdate()
        case .alertThirdButtonReturn:
            updates.skipCurrentVersion()
        default:
            break
        }
    }
}
