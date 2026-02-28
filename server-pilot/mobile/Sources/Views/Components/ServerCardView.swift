import SwiftUI

struct ServerCardView: View {
    let server: ServerInfo
    let onWake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(server.online ? .green : .red)
                    .frame(width: 10, height: 10)
            }

            HStack {
                Text(server.sshState)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if server.canWake {
                    Button("Wake") {
                        onWake()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
