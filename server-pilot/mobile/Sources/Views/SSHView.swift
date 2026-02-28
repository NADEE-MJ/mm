import SwiftUI

struct SSHView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 12) {
            TextField("Command", text: $command)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))

            Button {
                runCommand()
            } label: {
                if isRunning {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Run")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(command.isEmpty || isRunning)

            ScrollView {
                Text(output)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func runCommand() {
        isRunning = true

        Task {
            defer {
                Task { @MainActor in
                    isRunning = false
                }
            }

            do {
                let result = try await networkService.runSSHCommand(serverId: server.id, command: command)
                let merged = [
                    "exitCode: \(result.exitCode)",
                    result.stdout,
                    result.stderr.isEmpty ? "" : "stderr:\n\(result.stderr)",
                ]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")

                await MainActor.run {
                    output = merged
                }
            } catch {
                await MainActor.run {
                    output = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
