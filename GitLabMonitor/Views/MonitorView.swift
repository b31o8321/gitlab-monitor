import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("com.gitlab-monitor.openSettings")
    static let refreshRequested = Notification.Name("com.gitlab-monitor.refreshRequested")
}

struct MonitorView: View {
    @ObservedObject var store: RepositoryStore

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
}
