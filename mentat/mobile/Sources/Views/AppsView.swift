import SwiftUI

struct AppsView: View {
    let networkService: NetworkService

    @State private var apps: [IpaApp] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Build state
    @State private var buildingAppId: String?
    @State private var buildResult: BuildResult?
    @State private var buildResultApp: IpaApp?

    // Share state
    @State private var sharingAppId: String?
    @State private var activeShareLink: IpaShareLink?
    @State private var shareSourceApp: IpaApp?

    // Confirmation
    @State private var pendingBuildApp: IpaApp?

    var body: some View {
        NavigationStack {
            Group {
                if apps.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Apps Configured",
                        systemImage: "app.badge.fill",
                        description: Text("Add apps to your servers.json to get started.")
                    )
                } else {
                    List(apps) { app in
                        AppRowView(
                            app: app,
                            isBuilding: buildingAppId == stableId(app),
                            isSharing: sharingAppId == stableId(app),
                            onBuild: { pendingBuildApp = app },
                            onShare: { Task { await share(app) } }
                        )
                    }
                }
            }
            .navigationTitle("Apps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await refresh()
            }
            // Build confirmation alert
            .alert(
                buildingConfirmTitle,
                isPresented: Binding(get: { pendingBuildApp != nil }, set: { if !$0 { pendingBuildApp = nil } })
            ) {
                Button("Cancel", role: .cancel) { pendingBuildApp = nil }
                Button("Build", role: .destructive) {
                    let app = pendingBuildApp
                    pendingBuildApp = nil
                    if let app { Task { await build(app) } }
                }
            } message: {
                if let app = pendingBuildApp {
                    Text("Run the build command for \(app.displayName) on \(app.serverName)?")
                }
            }
            // Build result sheet
            .sheet(item: $buildResultApp) { app in
                BuildResultSheet(app: app, result: buildResult) {
                    buildResultApp = nil
                    buildResult = nil
                }
            }
            // Share link sheet
            .sheet(item: $shareSourceApp) { app in
                if let link = activeShareLink {
                    ShareLinkSheet(app: app, link: link) {
                        shareSourceApp = nil
                        activeShareLink = nil
                    }
                }
            }
            // Error banner
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .padding(10)
                        .background(.red.opacity(0.12), in: Capsule())
                        .padding(.bottom, 12)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                self.errorMessage = nil
                            }
                        }
                }
            }
        }
    }

    // MARK: - Helpers

    private var buildingConfirmTitle: String {
        pendingBuildApp.map { "Build \($0.displayName)?" } ?? "Build?"
    }

    /// A stable string key for (serverId, appId) to track per-row loading state.
    private func stableId(_ app: IpaApp) -> String { "\(app.serverId):\(app.id)" }

    // MARK: - Actions

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            apps = try await networkService.fetchApps()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func build(_ app: IpaApp) async {
        buildingAppId = stableId(app)
        defer { buildingAppId = nil }
        do {
            let result = try await networkService.buildApp(serverId: app.serverId, appId: app.id)
            buildResult = result
            buildResultApp = app
            // Refresh list to pick up the updated lastBuiltAt.
            apps = (try? await networkService.fetchApps()) ?? apps
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func share(_ app: IpaApp) async {
        sharingAppId = stableId(app)
        defer { sharingAppId = nil }
        do {
            let link = try await networkService.shareApp(serverId: app.serverId, appId: app.id)
            activeShareLink = link
            shareSourceApp = app
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - App Row

private struct AppRowView: View {
    let app: IpaApp
    let isBuilding: Bool
    let isSharing: Bool
    let onBuild: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.headline)
                    Text(app.serverName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                buildStatusBadge
            }

            if let date = app.lastBuiltDate {
                Text("Built \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                // Build button
                Button {
                    onBuild()
                } label: {
                    if isBuilding {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Building…")
                        }
                    } else {
                        Label("Build", systemImage: "hammer")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isBuilding || isSharing)

                // Share / get link button
                Button {
                    onShare()
                } label: {
                    if isSharing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Getting link…")
                        }
                    } else {
                        Label("Get Link", systemImage: "link")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(!app.copypartyConfigured || isBuilding || isSharing)
            }

            if !app.copypartyConfigured {
                Text("COPYPARTY_URL not set — link sharing unavailable")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var buildStatusBadge: some View {
        if let success = app.lastBuildSucceeded {
            Text(success ? "Built" : "Failed")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(success ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundStyle(success ? .green : .red)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Build Result Sheet

private struct BuildResultSheet: View {
    let app: IpaApp
    let result: BuildResult?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let result {
                        HStack {
                            Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.ok ? .green : .red)
                                .font(.title2)
                            Text(result.ok ? "Build succeeded" : "Build failed (exit \(result.exitCode))")
                                .font(.headline)
                        }

                        if let output = result.output, !output.isEmpty {
                            Text(output)
                                .font(.caption.monospaced())
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(app.displayName) Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

// MARK: - Share Link Sheet

private struct ShareLinkSheet: View {
    let app: IpaApp
    let link: IpaShareLink
    let onDismiss: () -> Void

    @State private var copied = false

    private var expiresDate: Date? {
        ISO8601DateFormatter().date(from: link.expiresAt)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                VStack(spacing: 6) {
                    Text(app.displayName)
                        .font(.title2.weight(.semibold))
                    if let expires = expiresDate {
                        Text("Expires \(expires.formatted(.relative(presentation: .named)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // The link itself
                Text(link.url)
                    .font(.caption.monospaced())
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    // Copy to clipboard
                    Button {
                        UIPasteboard.general.string = link.url
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .animation(.default, value: copied)

                    // Share sheet (for AirDrop, Messages, etc.)
                    ShareLink(item: URL(string: link.url) ?? URL(string: "about:blank")!) {
                        Label("Share via…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Download Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
