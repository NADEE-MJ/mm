import SwiftUI

// MARK: - Account Page
// Profile, stats, settings, dev tools.
// Matches the test app's Profile page style with FrostedCards.

struct AccountPageView: View {
    @State private var authManager = AuthManager.shared
    @State private var dbManager = DatabaseManager.shared
    @State private var ws = WebSocketManager.shared
    @State private var movies: [Movie] = []
    @State private var people: [Person] = []
    @State private var showClearCacheAlert = false
    @State private var showLogoutAlert = false
    @Environment(ScrollState.self) private var scrollState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Profile header
                    profileHeader

                    // Stats cards
                    statsSection

                    // Quick actions
                    actionsSection

                    // App info
                    appSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .background { PageBackground() }
            .navigationTitle("Account")
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        FrostedCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(userInitials)
                            .font(.headline)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.user?.username ?? "Movie Manager")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(authManager.user?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }
            .padding(14)
        }
    }

    private var userInitials: String {
        guard let name = authManager.user?.username, !name.isEmpty else { return "MM" }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistics")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            FrostedCard {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 0) {
                    statCell(
                        value: "\(movies.count)",
                        label: "Total Movies",
                        icon: "film.fill",
                        color: .blue
                    )
                    statCell(
                        value: "\(movies.filter { $0.status == "to_watch" }.count)",
                        label: "To Watch",
                        icon: "bookmark.fill",
                        color: .orange
                    )
                    statCell(
                        value: "\(movies.filter { $0.status == "watched" }.count)",
                        label: "Watched",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    statCell(
                        value: "\(people.count)",
                        label: "Recommenders",
                        icon: "person.2.fill",
                        color: .purple
                    )
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            FrostedCard {
                VStack(spacing: 0) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        actionRow(icon: "gearshape.fill", title: "Settings", color: .gray)
                    }

                    DividerLine()

                    NavigationLink {
                        DevToolsView()
                    } label: {
                        actionRow(icon: "hammer.fill", title: "Developer Labs", color: .orange)
                    }

                    DividerLine()

                    Button {
                        showClearCacheAlert = true
                    } label: {
                        actionRow(icon: "trash.fill", title: "Clear Local Cache", color: .red)
                    }

                    DividerLine()

                    Button {
                        showLogoutAlert = true
                    } label: {
                        actionRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Sign Out",
                            color: .red
                        )
                    }
                }
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            FrostedCard {
                VStack(spacing: 0) {
                    infoRow(label: "Version", value: "1.0.0")
                    DividerLine()
                    infoRow(label: "Cached Movies", value: "\(dbManager.movieCount)")
                    DividerLine()
                    infoRow(label: "Cached People", value: "\(dbManager.peopleCount)")
                    DividerLine()
                    infoRow(
                        label: "Sync Status",
                        value: ws.isConnected ? "Connected" : "Disconnected"
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func actionRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(14)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .font(.subheadline)
        .padding(14)
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

            Section("Privacy & Security") {
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
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (Build 26)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Platform")
                    Spacer()
                    Text("iOS 26")
                        .foregroundStyle(.secondary)
                }
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
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                Label("SQLite", systemImage: "cylinder.split.1x2").tag(0)
                Label("WebSocket", systemImage: "bolt.horizontal").tag(1)
                Label("Logs", systemImage: "text.alignleft").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            switch selectedSection {
            case 0: sqliteSection
            case 1: webSocketSection
            case 2: logsSection
            default: EmptyView()
            }
        }
        .background { PageBackground() }
        .navigationTitle("Developer Labs")
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            loggingEnabled = DebugSettings.loggingEnabled
            logURL = FileLogStore.shared.exportURL()
        }
    }

    // MARK: - SQLite Section

    private var sqliteSection: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GRDB.swift")
                            .font(.headline)
                        Text("Type-safe SQLite wrapper")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Stats") {
                HStack {
                    Text("Cached Movies")
                    Spacer()
                    Text("\(dbManager.movieCount)")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                HStack {
                    Text("Cached People")
                    Spacer()
                    Text("\(dbManager.peopleCount)")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Section {
                if dbManager.movieCount > 0 || dbManager.peopleCount > 0 {
                    Button(role: .destructive) {
                        withAnimation { dbManager.clearAll() }
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - WebSocket Section

    private var webSocketSection: some View {
        VStack(spacing: 0) {
            List {
                Section("Connection") {
                    HStack {
                        Circle()
                            .fill(ws.isConnected ? .green : .red)
                            .frame(width: 10, height: 10)
                        Text(ws.isConnected ? "Connected" : "Disconnected")
                            .font(.subheadline)
                        Spacer()

                        if ws.isConnected {
                            Button("Ping") { ws.ping() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }

                        Button(ws.isConnected ? "Disconnect" : "Connect") {
                            if ws.isConnected { ws.disconnect() }
                            else { ws.connect() }
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
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: msg.isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundStyle(msg.isOutgoing ? .blue : .green)
                                    .font(.caption)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.text).font(.subheadline)
                                    Text(msg.timestamp.formatted(.dateTime.hour().minute().second()))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                        }

                        Button("Clear Messages") {
                            withAnimation { ws.clearMessages() }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            // Input bar
            if ws.isConnected {
                HStack(spacing: 10) {
                    TextField("Type a message...", text: $wsInput)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .glassEffect(.regular, in: .capsule)

                    Button {
                        guard !wsInput.isEmpty else { return }
                        ws.send(wsInput)
                        wsInput = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(wsInput.isEmpty ? .gray : AppTheme.blue)
                    }
                    .disabled(wsInput.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        List {
            Section("Console") {
                Text("Live logs are written via os.Logger and can be viewed with idevicesyslog.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
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
                            AppLog.info("🧪 [Debug] Verbose logging enabled", category: .debug)
                        } else {
                            AppLog.warning("🧪 [Debug] Verbose logging disabled", category: .debug)
                        }
                    }

                Button {
                    AppLog.debug("🧪 [Debug] Manual test log entry", category: .debug)
                    logURL = FileLogStore.shared.exportURL()
                } label: {
                    Label("Write Test Log Entry", systemImage: "pencil.and.list.clipboard")
                }
                #else
                Text("Verbose logging controls are available in Debug builds.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                #endif
            }

            Section("Export") {
                HStack {
                    Text("Log File")
                    Spacer()
                    Text(logURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ShareLink(item: logURL) {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    FileLogStore.shared.clear()
                    AppLog.warning("🧪 [Debug] Log file cleared", category: .debug)
                    logURL = FileLogStore.shared.exportURL()
                } label: {
                    Label("Clear Log File", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    AccountPageView()
}
