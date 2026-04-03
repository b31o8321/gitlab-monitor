import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: RepositoryStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitLab Monitor")
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showSettings = true }) {
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
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }
}

// MARK: - Temporary placeholder (replaced in Task 9)
private struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    var body: some View { Text("Settings coming soon").padding() }
}
