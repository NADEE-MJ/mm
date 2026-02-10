import SwiftUI

// MARK: - Account Page

struct AccountPageView: View {
    var onClose: (() -> Void)? = nil

    @State private var authManager = AuthManager.shared
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
            .navigationBarTitleDisplayMode(onClose == nil ? .large : .inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            onClose()
                        }
                        label: { Text("Close") }
                    }
                }
            }
            .task {
                await loadData()
            }
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    dbManager.clearAll()
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
        await NetworkService.shared.fetchMovies()
        movies = NetworkService.shared.movies
        await NetworkService.shared.fetchPeople()
        people = NetworkService.shared.people
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @State private var bioManager = BiometricAuthManager()

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

            Section("About") {
                LabeledContent("Version") { Text("1.0.0 (Build 26)").foregroundStyle(.secondary) }
                LabeledContent("Platform") { Text("iOS 26").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
    }
}

// MARK: - Developer Tools View

struct DevToolsView: View {
    @State private var dbManager = DatabaseManager.shared
    @State private var ws = WebSocketManager.shared
    @State private var selectedSection = 0
    @State private var wsInput = ""
    @State private var loggingEnabled = DebugSettings.loggingEnabled
    @State private var logURL = FileLogStore.shared.exportURL()

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
                    withAnimation { dbManager.clearAll() }
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
            Text("idevicesyslog | grep -i \"\(Bundle.main.bundleIdentifier ?? "com.moviemanager.mobileswift")\"")
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
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

            Button("Clear Log File", role: .destructive) {
                FileLogStore.shared.clear()
                AppLog.warning("[Debug] Log file cleared", category: .debug)
                logURL = FileLogStore.shared.exportURL()
            }
        }
    }
}

#Preview {
    AccountPageView()
}
