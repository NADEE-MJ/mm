import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Account Page

struct AccountPageView: View {
    var onClose: (() -> Void)? = nil

    @State private var authManager = AuthManager.shared
    @State private var repository = MovieRepository.shared
    @State private var dbManager = DatabaseManager.shared
    @State private var ws = WebSocketManager.shared
    @State private var movies: [Movie] = []
    @State private var people: [Person] = []
    @State private var showClearCacheAlert = false
    @State private var showLogoutAlert = false

    private var isSyncConnected: Bool { ws.isConnected }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authManager.user?.username ?? "Movie Manager")
                                .font(.headline)
                            Text(authManager.user?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Statistics") {
                    LabeledContent("Total Movies") { Text("\(movies.count)") }
                    LabeledContent("To Watch") {
                        Text("\(movies.filter { $0.status == "to_watch" }.count)")
                    }
                    LabeledContent("Watched") {
                        Text("\(movies.filter { $0.status == "watched" }.count)")
                    }
                    LabeledContent("People") { Text("\(people.count)") }
                }

                Section("Quick Actions") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    NavigationLink {
                        DevToolsView()
                    } label: {
                        Label("Developer Tools", systemImage: "hammer")
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label("Clear Local Cache", systemImage: "trash")
                    }

                    Button {
                        URLCache.shared.removeAllCachedResponses()
                    } label: {
                        Label("Clear Image Cache", systemImage: "photo.badge.exclamationmark")
                    }

                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("App") {
                    LabeledContent("Version") { Text("1.0.0") }
                    LabeledContent("Cached Movies") { Text("\(dbManager.movieCount)") }
                    LabeledContent("Cached People") { Text("\(dbManager.peopleCount)") }
                    LabeledContent("Sync Status") {
                        Label(
                            isSyncConnected ? "Connected" : "Disconnected",
                            systemImage: isSyncConnected ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(isSyncConnected ? .green : .red)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
            .task {
                await loadData()
            }
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    repository.clearLocalCache()
                }
            } message: {
                Text("This removes all locally cached movies and people.")
            }
            .alert("Sign Out?", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("You will need to sign in again to access your data.")
            }
        }
    }

    private func loadData() async {
        switch await repository.getMovies(status: nil) {
        case .success(let loaded):
            movies = loaded
        case .failure:
            movies = repository.movies
        }

        switch await repository.getPeople() {
        case .success(let loaded):
            people = loaded
        case .failure:
            people = repository.people
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @State private var bioManager = BiometricAuthManager()
    @State private var networkService = NetworkService.shared
    @State private var repository = MovieRepository.shared
    @State private var backupEnabled = false
    @State private var backupSettingsLoaded = false
    @State private var isLoadingBackupSettings = false
    @State private var isUpdatingBackupSettings = false
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var showBackupImporter = false
    @State private var showShareSheet = false
    @State private var exportedBackupURL: URL?
    @State private var showBackupAlert = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Push Notifications", isOn: $notifications)
                Toggle("Haptic Feedback", isOn: $haptics)
            }

            Section("Privacy and Security") {
                Toggle(isOn: $faceIDEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: bioManager.biometryIcon)
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bioManager.biometryLabel)
                            Text("Require authentication to open the app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: faceIDEnabled) { _, newValue in
                    bioManager.setBiometricEnabled(newValue)
                }
            }

            Section("Data & Backup") {
                Toggle("Auto-backup", isOn: $backupEnabled)
                    .disabled(isLoadingBackupSettings || isUpdatingBackupSettings)
                    .onChange(of: backupEnabled) { oldValue, newValue in
                        guard backupSettingsLoaded, oldValue != newValue else { return }
                        Task {
                            await updateBackupSettings(newValue: newValue, oldValue: oldValue)
                        }
                    }

                Text("Saves your library daily on the server (14 days retained)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await exportBackup() }
                } label: {
                    Label(
                        isExportingBackup ? "Exporting..." : "Export Library",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .disabled(isExportingBackup)

                Button {
                    showBackupImporter = true
                } label: {
                    Label(
                        isImportingBackup ? "Importing..." : "Import Library",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(isImportingBackup)
            }

            Section("About") {
                LabeledContent("Version") { Text("1.0.0 (Build 26)").foregroundStyle(.secondary) }
                LabeledContent("Platform") { Text("iOS 26").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadBackupSettings()
        }
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result {
                    presentBackupAlert(
                        title: "Import Failed",
                        message: error.localizedDescription
                    )
                }
                return
            }

            Task {
                await importBackup(from: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportedBackupURL {
                ActivityViewController(items: [exportedBackupURL])
            }
        }
        .alert(backupAlertTitle, isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupAlertMessage)
        }
    }

    private func loadBackupSettings() async {
        guard !backupSettingsLoaded else { return }
        isLoadingBackupSettings = true
        defer { isLoadingBackupSettings = false }

        do {
            let settings = try await networkService.getBackupSettings()
            backupEnabled = settings.backupEnabled
            backupSettingsLoaded = true
        } catch {
            backupSettingsLoaded = true
            presentBackupAlert(
                title: "Settings Unavailable",
                message: error.localizedDescription
            )
        }
    }

    private func updateBackupSettings(newValue: Bool, oldValue: Bool) async {
        isUpdatingBackupSettings = true
        defer { isUpdatingBackupSettings = false }

        do {
            try await networkService.updateBackupSettings(enabled: newValue)
        } catch {
            backupEnabled = oldValue
            presentBackupAlert(
                title: "Update Failed",
                message: error.localizedDescription
            )
        }
    }

    private func exportBackup() async {
        isExportingBackup = true
        defer { isExportingBackup = false }

        do {
            let data = try await networkService.exportBackup()
            let fileURL = try writeBackupExportToTemporaryFile(data: data)
            exportedBackupURL = fileURL
            showShareSheet = true
        } catch {
            presentBackupAlert(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func writeBackupExportToTemporaryFile(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let filename = "moviemanager-export-\(dateString).json"

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func importBackup(from url: URL) async {
        isImportingBackup = true
        defer { isImportingBackup = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let rawObject = try JSONSerialization.jsonObject(with: data)
            guard let payload = rawObject as? [String: Any] else {
                throw NSError(
                    domain: "BackupImport",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "The selected file is not a JSON object."]
                )
            }

            let result = try await networkService.importBackup(payload)
            if !result.success {
                let message = result.errors.joined(separator: "; ")
                throw NSError(
                    domain: "BackupImport",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Import failed." : message]
                )
            }
            await repository.syncNow()

            if !result.imdbIdsNeedingEnrichment.isEmpty {
                for imdbId in result.imdbIdsNeedingEnrichment {
                    _ = await networkService.refreshMovieMetadata(imdbId: imdbId)
                }
                await repository.syncNow()
            }

            let counts = result.importedCounts
            var message = "Imported \(counts.movies) movies, \(counts.people) people, \(counts.lists) lists."
            if !result.imdbIdsNeedingEnrichment.isEmpty {
                message += " Refreshing movie data for \(result.imdbIdsNeedingEnrichment.count) items."
            }
            if !result.errors.isEmpty {
                message += " Warnings: \(result.errors.joined(separator: "; "))"
            }

            presentBackupAlert(title: "Import Complete", message: message)
        } catch {
            presentBackupAlert(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func presentBackupAlert(title: String, message: String) {
        backupAlertTitle = title
        backupAlertMessage = message
        showBackupAlert = true
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Developer Tools View

struct DevToolsView: View {
    @State private var dbManager = DatabaseManager.shared
    @State private var repository = MovieRepository.shared
    @State private var ws = WebSocketManager.shared
    @State private var selectedSection = 0
    @State private var wsInput = ""
    @State private var loggingEnabled = DebugSettings.loggingEnabled
    @State private var logURL = FileLogStore.shared.exportURL()
    private let fileLoggingEnabled = FileLogStore.shared.isEnabled

    var body: some View {
        List {
            Section {
                Picker("Section", selection: $selectedSection) {
                    Label("SQLite", systemImage: "cylinder.split.1x2").tag(0)
                    Label("WebSocket", systemImage: "bolt.horizontal").tag(1)
                    Label("Logs", systemImage: "text.alignleft").tag(2)
                }
                .pickerStyle(.segmented)
            }

            switch selectedSection {
            case 0:
                sqliteContent
            case 1:
                webSocketContent
            case 2:
                logsContent
            default:
                EmptyView()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Tools")
        .toolbarTitleDisplayMode(.inline)
        .animation(.default, value: selectedSection)
        .onAppear {
            loggingEnabled = DebugSettings.loggingEnabled
            logURL = FileLogStore.shared.exportURL()
        }
    }

    // MARK: - SQLite

    @ViewBuilder
    private var sqliteContent: some View {
        Section {
            Label("GRDB.swift", systemImage: "cylinder.split.1x2.fill")
            Text("Type-safe SQLite wrapper")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Stats") {
            LabeledContent("Cached Movies") { Text("\(dbManager.movieCount)") }
            LabeledContent("Cached People") { Text("\(dbManager.peopleCount)") }
        }

        if dbManager.movieCount > 0 || dbManager.peopleCount > 0 {
            Section {
                Button("Clear All Data", role: .destructive) {
                    withAnimation { repository.clearLocalCache() }
                }
            }
        }
    }

    // MARK: - WebSocket

    @ViewBuilder
    private var webSocketContent: some View {
        Section("Connection") {
            HStack {
                Circle()
                    .fill(ws.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(ws.isConnected ? "Connected" : "Disconnected")
                Spacer()

                if ws.isConnected {
                    Button("Ping") { ws.ping() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button(ws.isConnected ? "Disconnect" : "Connect") {
                    if ws.isConnected {
                        ws.disconnect()
                    } else {
                        ws.connect()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ws.isConnected ? .red : .green)
                .controlSize(.small)
            }

            if let err = ws.lastError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }

        Section("Messages (\(ws.messages.count))") {
            if ws.messages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Connect and send a message.")
                )
            } else {
                ForEach(ws.messages) { msg in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: msg.isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(msg.isOutgoing ? .blue : .green)
                            Text(msg.text)
                        }
                        Text(msg.timestamp.formatted(.dateTime.hour().minute().second()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Clear Messages", role: .destructive) {
                    withAnimation { ws.clearMessages() }
                }
            }
        }

        if ws.isConnected {
            Section("Send Message") {
                TextField("Type a message...", text: $wsInput)
                Button("Send") {
                    guard !wsInput.isEmpty else { return }
                    ws.send(wsInput)
                    wsInput = ""
                }
                .disabled(wsInput.isEmpty)
            }
        }
    }

    // MARK: - Logs

    @ViewBuilder
    private var logsContent: some View {
        Section("Console") {
            Text("Live logs are written via os.Logger and can be viewed with idevicesyslog.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("idevicesyslog | grep -i \"\(Bundle.main.bundleIdentifier ?? "com.moviemanager.app")\"")
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            Text(fileLoggingEnabled ? "File export keeps only today's logs." : "File export is disabled for this build.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section("Logging") {
            #if DEBUG
            Toggle("Enable verbose logging", isOn: $loggingEnabled)
                .onChange(of: loggingEnabled) { _, newValue in
                    DebugSettings.loggingEnabled = newValue
                    if newValue {
                        AppLog.info("[Debug] Verbose logging enabled", category: .debug)
                    } else {
                        AppLog.warning("[Debug] Verbose logging disabled", category: .debug)
                    }
                }

            Button {
                AppLog.debug("[Debug] Manual test log entry", category: .debug)
                logURL = FileLogStore.shared.exportURL()
            } label: {
                Label("Write Test Log Entry", systemImage: "pencil.and.list.clipboard")
            }
            #else
            Text("Verbose logging controls are available in Debug builds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
        }

        Section("Export") {
            LabeledContent("Log File") {
                Text(logURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ShareLink(item: logURL) {
                Label("Export Logs", systemImage: "square.and.arrow.up")
            }
            .disabled(!fileLoggingEnabled)

            Button("Clear Log File", role: .destructive) {
                FileLogStore.shared.clear()
                AppLog.warning("[Debug] Log file cleared", category: .debug)
                logURL = FileLogStore.shared.exportURL()
            }
            .disabled(!fileLoggingEnabled)
        }
    }
}

#Preview {
    AccountPageView()
}
