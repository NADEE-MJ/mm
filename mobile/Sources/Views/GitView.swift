import SwiftUI

struct GitView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var repos: [GitRepoState] = []
    @State private var branchInputs: [String: String] = [:]
    @State private var isLoading = false
    @State private var outputMessage = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(repos) { repo in
                VStack(alignment: .leading, spacing: 8) {
                    Text(repo.name)
                        .font(.headline)

                    Text(repo.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Branch:")
                            .font(.caption)
                        Text(repo.branch)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tint)
                    }

                    HStack {
                        Button("Pull") {
                            Task { await pull(repo: repo) }
                        }
                        .buttonStyle(.bordered)

                        TextField("branch", text: Binding(
                            get: { branchInputs[repo.name] ?? repo.branch },
                            set: { branchInputs[repo.name] = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)

                        Button("Checkout") {
                            Task { await checkout(repo: repo) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if !outputMessage.isEmpty {
                    Text(outputMessage)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .background(.clear)
        }
        .refreshable {
            await refresh()
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            repos = try await networkService.fetchGitRepos(serverId: server.id)
            for repo in repos where branchInputs[repo.name] == nil {
                branchInputs[repo.name] = repo.branch
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pull(repo: GitRepoState) async {
        do {
            outputMessage = try await networkService.gitPull(serverId: server.id, repoName: repo.name)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkout(repo: GitRepoState) async {
        let branch = (branchInputs[repo.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return }

        do {
            outputMessage = try await networkService.gitCheckout(serverId: server.id, repoName: repo.name, branch: branch)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
