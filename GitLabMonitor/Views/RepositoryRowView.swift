import SwiftUI

struct RepositoryRowView: View {
    let state: RepositoryState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(state.status.color)
                    .frame(width: 10, height: 10)
                Text(state.repository.name)
                    .fontWeight(.medium)
                Spacer()
                Text(state.repository.branch)
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(state.status.symbol + " " + state.status.label)
                    .font(.caption)
                    .foregroundColor(state.status.color)
            }
            HStack {
                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if let updatedAt = state.updatedAt {
                    Text(updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let webUrl = state.webUrl, let url = URL(string: webUrl) {
                    Link("↗", destination: url)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
