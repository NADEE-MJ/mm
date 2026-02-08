import SwiftUI
import NukeUI

// MARK: - Developer Tools / Labs
// Three-section demo: SQLite (GRDB), REST API (Nuke for images), WebSocket.

struct DevToolsView: View {
    @State private var dbManager = DatabaseManager.shared
    @State private var network = NetworkService.shared
    @State private var ws = WebSocketManager.shared
    @State private var selectedSection = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                Label("SQLite", systemImage: "cylinder.split.1x2").tag(0)
                Label("API", systemImage: "arrow.up.arrow.down").tag(1)
                Label("WebSocket", systemImage: "bolt.horizontal").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            switch selectedSection {
            case 0: sqliteSection
            case 1: apiSection
            case 2: webSocketSection
            default: EmptyView()
            }
        }
        .background { PageBackground() }
        .navigationTitle("Developer Labs")
        .toolbarTitleDisplayMode(.inline)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 1. SQLite Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
                        Text("Type-safe Swift wrapper over SQLite — via SPM")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Bookmark a Repo") {
                Button {
                    dbManager.addBookmark(
                        id: UUID().uuidString,
                        name: "mm",
                        owner: "NADEE-MJ",
                        language: "TypeScript",
                        stars: Int.random(in: 1...100)
                    )
                } label: {
                    Label("Add Random Bookmark", systemImage: "plus.circle.fill")
                }

                Button {
                    dbManager.addBookmark(
                        id: UUID().uuidString,
                        name: ["swift-test", "discord-bot", "raddle.teams", "zsh", "ml-notebook"].randomElement()!,
                        owner: "NADEE-MJ",
                        language: ["Swift", "Python", "TypeScript", "Shell"].randomElement()!,
                        stars: Int.random(in: 0...50)
                    )
                } label: {
                    Label("Add Varied Bookmark", systemImage: "plus.circle")
                }

                if !dbManager.bookmarks.isEmpty {
                    Button(role: .destructive) {
                        withAnimation { dbManager.clearAll() }
                    } label: {
                        Label("Clear All (\(dbManager.bookmarkCount))", systemImage: "trash")
                    }
                }
            }

            Section("Stored Bookmarks (\(dbManager.bookmarkCount))") {
                if dbManager.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark.slash",
                        description: Text("Tap the buttons above to write to SQLite.")
                    )
                } else {
                    ForEach(dbManager.bookmarks) { bm in
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(bm.owner)/\(bm.name)")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(bm.language)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Label("\(bm.stars)", systemImage: "star")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                            Spacer()
                            Text(bm.bookmarkedAt.formatted(.dateTime.hour().minute()))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { dbManager.removeBookmark(id: bm.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 2. REST API Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var apiSection: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("URLSession + NukeUI")
                            .font(.headline)
                        Text("API via URLSession, images via Nuke (disk + memory cache)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Actions") {
                Button {
                    Task { await network.fetchUser("NADEE-MJ") }
                } label: {
                    HStack {
                        Label("Fetch User Profile", systemImage: "person.circle")
                        Spacer()
                        if network.isLoading {
                            ProgressView()
                        }
                    }
                }

                Button {
                    Task { await network.fetchRepos("NADEE-MJ") }
                } label: {
                    HStack {
                        Label("Fetch Repositories", systemImage: "folder")
                        Spacer()
                        if network.isLoading {
                            ProgressView()
                        }
                    }
                }
            }

            if let error = network.lastError {
                Section("Error") {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if let user = network.fetchedUser {
                Section("User") {
                    HStack(spacing: 12) {
                        LazyImage(url: URL(string: user.avatarUrl)) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else if state.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(.circle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name ?? user.login).font(.headline)
                            Text("@\(user.login)").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                            if let bio = user.bio {
                                Text(bio).font(.caption).foregroundStyle(AppTheme.textTertiary).lineLimit(2)
                            }
                        }
                    }

                    HStack(spacing: 20) {
                        Label("\(user.publicRepos) repos", systemImage: "folder")
                        Label("\(user.followers) followers", systemImage: "person.2")
                        Label("\(user.following) following", systemImage: "person.badge.plus")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if !network.fetchedRepos.isEmpty {
                Section("Repos (live from API)") {
                    ForEach(network.fetchedRepos) { repo in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(repo.name).font(.headline)
                                Spacer()
                                Label("\(repo.stargazersCount)", systemImage: "star")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            if let desc = repo.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                Text(repo.language ?? "—")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textTertiary)
                                Label("\(repo.forksCount) forks", systemImage: "tuningfork")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 3. WebSocket Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @State private var wsInput = ""

    private var webSocketSection: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.title)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("URLSessionWebSocketTask")
                                .font(.headline)
                            Text("Built-in WebSocket API — echo server demo")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                            description: Text("Connect and send a message to see the echo response.")
                        )
                    } else {
                        ForEach(ws.messages) { msg in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: msg.isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundStyle(msg.isOutgoing ? .blue : .green)
                                    .font(.caption)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.text)
                                        .font(.subheadline)
                                    Text(msg.timestamp.formatted(.dateTime.hour().minute().second()))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                        }
                    }

                    if !ws.messages.isEmpty {
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
                    TextField("Type a message…", text: $wsInput)
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
}
