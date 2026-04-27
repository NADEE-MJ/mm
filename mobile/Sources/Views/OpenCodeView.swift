import SwiftUI

// MARK: - Main Tab View

struct OpenCodeView: View {
    let networkService: NetworkService

    @State private var sessions: [OpenCodeSession] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewSessionSheet = false
    @State private var selectedSession: OpenCodeSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty && !isLoading {
                    ContentUnavailableView {
                        Label("No Sessions", systemImage: "chevron.left.forwardslash.chevron.right")
                    } description: {
                        Text("Tap + to start a new OpenCode session.")
                    } actions: {
                        Button("New Session") { showNewSessionSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    sessionList
                }
            }
            .navigationTitle("OpenCode")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewSessionSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadSessions() }
            .refreshable { await loadSessions() }
            .overlay(alignment: .bottom) {
                errorBanner
            }
            .sheet(isPresented: $showNewSessionSheet) {
                NewSessionSheet(networkService: networkService) { session in
                    sessions.insert(session, at: 0)
                    selectedSession = session
                }
            }
            .navigationDestination(item: $selectedSession) { session in
                OpenCodeChatView(session: session, networkService: networkService) { updated in
                    if let idx = sessions.firstIndex(where: { $0.id == updated.id }) {
                        sessions[idx] = updated
                    }
                } onDeleted: { id in
                    sessions.removeAll { $0.id == id }
                }
            }
        }
    }

    // MARK: Session list

    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    SessionRowView(session: session)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                Task { await deleteSession(at: indexSet) }
            }
        }
        .overlay {
            if isLoading { ProgressView() }
        }
    }

    private var errorBanner: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.red.opacity(0.12), in: Capsule())
                    .padding(.bottom, 12)
                    .onTapGesture { self.errorMessage = nil }
            }
        }
    }

    // MARK: Data

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await networkService.fetchOpenCodeSessions()
            // Sort newest first.
            sessions = fetched.sorted { $0.time.updated > $1.time.updated }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSession(at indexSet: IndexSet) async {
        let toDelete = indexSet.map { sessions[$0] }
        do {
            for session in toDelete {
                try await networkService.deleteOpenCodeSession(id: session.id)
            }
            sessions.remove(atOffsets: indexSet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Session Row

private struct SessionRowView: View {
    let session: OpenCodeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionTitle)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(session.directory)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var sessionTitle: String {
        session.title.isEmpty ? "Untitled Session" : session.title
    }

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: session.time.updated)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - New Session Sheet

private struct NewSessionSheet: View {
    let networkService: NetworkService
    let onCreate: (OpenCodeSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session title (optional)", text: $title)
                        .autocorrectionDisabled()
                } header: {
                    Text("New Session")
                } footer: {
                    Text("OpenCode will use its current working directory. To open in a specific folder, configure the working directory in your OpenCode server setup.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createSession() }
                    }
                    .disabled(isCreating)
                    .overlay { if isCreating { ProgressView().scaleEffect(0.7) } }
                }
            }
        }
    }

    private func createSession() async {
        isCreating = true
        defer { isCreating = false }
        do {
            let session = try await networkService.createOpenCodeSession(
                title: title.isEmpty ? nil : title
            )
            onCreate(session)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Chat View

struct OpenCodeChatView: View {
    let session: OpenCodeSession
    let networkService: NetworkService
    let onUpdated: (OpenCodeSession) -> Void
    let onDeleted: (String) -> Void

    @State private var messages: [OpenCodeMessageEnvelope] = []
    @State private var isLoading = false
    @State private var isSending = false
    @State private var inputText = ""
    @State private var errorMessage: String?
    @State private var showModelPicker = false
    @State private var showAgentPicker = false
    @State private var providers: [OpenCodeProvider] = []
    @State private var agents: [OpenCodeAgent] = []
    @State private var currentModel: String? = nil
    @State private var selectedAgent: String? = nil
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var sessionStatus: OpenCodeSessionStatus = .idle

    // Working model label derived from currentModel string.
    private var modelLabel: String {
        guard let m = currentModel else { return "Model" }
        // Format: "providerID/modelID" → show modelID only
        return m.split(separator: "/").last.map(String.init) ?? m
    }

    var body: some View {
        VStack(spacing: 0) {
            messageThread
            Divider()
            inputBar
        }
        .navigationTitle(sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .task { await loadInitialData() }
        .onDisappear { streamTask?.cancel() }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(
                providers: providers,
                currentModel: currentModel,
                onSelect: { providerID, modelID in
                    Task { await selectModel(providerID: providerID, modelID: modelID) }
                }
            )
        }
        .sheet(isPresented: $showAgentPicker) {
            AgentPickerSheet(
                agents: agents,
                selectedAgent: selectedAgent,
                onSelect: { agent in selectedAgent = agent }
            )
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.red.opacity(0.12), in: Capsule())
                    .padding(.bottom, 80)
                    .onTapGesture { self.errorMessage = nil }
            }
        }
    }

    // MARK: Message thread

    private var messageThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages, id: \.info.id) { envelope in
                        MessageBubbleView(envelope: envelope)
                            .id(envelope.info.id)
                    }

                    if case .busy = sessionStatus {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Thinking…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 16)
                        .id("status-busy")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: sessionStatus) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message…", text: $inputText, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                .disabled(isSending)

            if case .busy = sessionStatus {
                Button { Task { await abortSession() } } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(.quaternary, in: Circle())
                }
            } else {
                Button { Task { await sendMessage() } } label: {
                    Image(systemName: "arrow.up")
                        .bold()
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor, in: Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button {
                    showModelPicker = true
                } label: {
                    Label(modelLabel, systemImage: "cpu")
                }

                Button {
                    showAgentPicker = true
                } label: {
                    Label(selectedAgent ?? "Agent", systemImage: "person.circle")
                }

                Divider()

                Button {
                    Task { await shareSession() }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Helpers

    private var sessionTitle: String {
        session.title.isEmpty ? "Session" : session.title
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.info.id, anchor: .bottom)
            }
        }
    }

    // MARK: Data loading

    private func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let msgs = networkService.fetchOpenCodeMessages(sessionId: session.id)
            async let provs = networkService.fetchOpenCodeProviders()
            async let agts = networkService.fetchOpenCodeAgents()
            async let cfg = networkService.fetchOpenCodeConfig()

            let (fetchedMsgs, fetchedProviders, fetchedAgents, fetchedConfig) = try await (msgs, provs, agts, cfg)

            messages = fetchedMsgs
            providers = fetchedProviders.all
            agents = fetchedAgents
            currentModel = fetchedConfig.model
        } catch {
            errorMessage = error.localizedDescription
        }

        // Start SSE event stream.
        startEventStream()
    }

    private func startEventStream() {
        streamTask?.cancel()
        streamTask = Task {
            guard let request = try? networkService.makeOpenCodeEventStreamRequest() else { return }

            do {
                let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
                var lineBuffer = ""

                for try await byte in asyncBytes {
                    guard !Task.isCancelled else { break }

                    if let char = String(bytes: [byte], encoding: .utf8) {
                        lineBuffer += char

                        if lineBuffer.hasSuffix("\n") {
                            let line = lineBuffer.trimmingCharacters(in: .newlines)
                            lineBuffer = ""

                            if line.hasPrefix("data: ") {
                                let jsonStr = String(line.dropFirst(6))
                                await handleSSEData(jsonStr)
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    // Reconnect after a short delay.
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled {
                        startEventStream()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleSSEData(_ json: String) async {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // GlobalEvent wrapper: { directory: string, payload: Event }
        let payload: [String: Any]
        if let p = obj["payload"] as? [String: Any] {
            payload = p
        } else {
            payload = obj
        }

        guard let type_ = payload["type"] as? String else { return }

        switch type_ {
        case "session.status":
            guard let props = payload["properties"] as? [String: Any],
                  let sid = props["sessionID"] as? String,
                  sid == session.id else { return }
            if let statusObj = props["status"] as? [String: Any],
               let statusType = statusObj["type"] as? String {
                switch statusType {
                case "idle":
                    sessionStatus = .idle
                    // Refresh messages when the session goes idle (response complete).
                    await refreshMessages()
                case "busy":
                    sessionStatus = .busy
                default:
                    sessionStatus = .idle
                }
            }

        case "message.updated":
            guard let props = payload["properties"] as? [String: Any] else { return }
            // Re-fetch messages to pick up the complete state.
            _ = props
            if case .idle = sessionStatus { await refreshMessages() }

        case "message.part.updated":
            // We rely on full refresh on idle for simplicity.
            break

        default:
            break
        }
    }

    private func refreshMessages() async {
        do {
            let fetched = try await networkService.fetchOpenCodeMessages(sessionId: session.id)
            messages = fetched
        } catch {
            // Non-fatal; stale messages still shown.
        }
    }

    // MARK: Actions

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        isSending = true
        defer { isSending = false }

        // Build model ref from selected model string.
        var modelRef: ModelRef? = nil
        if let m = currentModel, m.contains("/") {
            let parts = m.split(separator: "/", maxSplits: 1)
            modelRef = ModelRef(providerID: String(parts[0]), modelID: String(parts[1]))
        }

        do {
            try await networkService.sendOpenCodeMessage(
                sessionId: session.id,
                text: text,
                modelRef: modelRef,
                agent: selectedAgent
            )
            sessionStatus = .busy
        } catch {
            errorMessage = error.localizedDescription
            inputText = text // Restore on failure.
        }
    }

    private func abortSession() async {
        do {
            try await networkService.abortOpenCodeSession(sessionId: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectModel(providerID: String, modelID: String) async {
        do {
            try await networkService.updateOpenCodeModel(providerID: providerID, modelID: modelID)
            currentModel = "\(providerID)/\(modelID)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shareSession() async {
        do {
            let url = try await networkService.shareOpenCodeSession(sessionId: session.id)
            if !url.isEmpty {
                UIPasteboard.general.string = url
                errorMessage = nil
                // Show a brief confirmation via errorMessage (repurposed as toast).
                // In a real app you'd use a separate @State for success toasts.
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubbleView: View {
    let envelope: OpenCodeMessageEnvelope

    private var isUser: Bool { envelope.info.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                    .padding(.top, 4)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Text parts
                ForEach(textContent, id: \.id) { part in
                    Text(part.text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isUser ? Color.accentColor : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .foregroundStyle(isUser ? .white : .primary)
                        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                }

                // Reasoning parts (collapsed summary)
                if !reasoningContent.isEmpty {
                    DisclosureGroup("Reasoning") {
                        ForEach(reasoningContent, id: \.id) { part in
                            Text(part.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 4)
                }

                // Tool parts
                ForEach(toolContent, id: \.id) { part in
                    ToolCallView(part: part)
                }
            }
            .frame(maxWidth: .infinity)

            if isUser {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .padding(.top, 4)
            }
        }
    }

    private var textContent: [OpenCodePart.TextPart] {
        envelope.parts.compactMap {
            if case .text(let p) = $0, !(p.synthetic ?? false) { return p }
            return nil
        }
    }

    private var reasoningContent: [OpenCodePart.ReasoningPart] {
        envelope.parts.compactMap {
            if case .reasoning(let p) = $0 { return p }
            return nil
        }
    }

    private var toolContent: [OpenCodePart.ToolPart] {
        envelope.parts.compactMap {
            if case .tool(let p) = $0 { return p }
            return nil
        }
    }
}

// MARK: - Tool Call View

private struct ToolCallView: View {
    let part: OpenCodePart.ToolPart
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let output = part.state.output {
                Text(output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let err = part.state.errorMessage {
                Text(err)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
            }
        } label: {
            HStack(spacing: 6) {
                statusIcon
                Text(part.state.title ?? part.tool)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text(part.tool)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch part.state.status {
        case "pending":
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case "running":
            ProgressView()
                .scaleEffect(0.6)
        case "completed":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        default:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Model Picker Sheet

private struct ModelPickerSheet: View {
    let providers: [OpenCodeProvider]
    let currentModel: String?
    let onSelect: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredProviders) { provider in
                    Section(provider.name) {
                        ForEach(provider.sortedModels) { model in
                            modelRow(provider: provider, model: model)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search models")
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func modelRow(provider: OpenCodeProvider, model: OpenCodeModel) -> some View {
        let isSelected = currentModel == "\(provider.id)/\(model.id)"
        Button {
            onSelect(provider.id, model.id)
            dismiss()
        } label: {
            ModelRowLabel(modelName: model.name, modelID: model.id, isSelected: isSelected)
        }
    }

    private var filteredProviders: [OpenCodeProvider] {
        guard !searchText.isEmpty else { return providers.filter { !$0.models.isEmpty } }
        return providers.compactMap { provider in
            let matchingModels = provider.models.filter { (_, model) in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.id.localizedCaseInsensitiveContains(searchText) ||
                provider.name.localizedCaseInsensitiveContains(searchText)
            }
            guard !matchingModels.isEmpty else { return nil }
            return OpenCodeProvider(
                id: provider.id,
                name: provider.name,
                source: provider.source,
                models: matchingModels
            )
        }
    }
}

private struct ModelRowLabel: View {
    let modelName: String
    let modelID: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(modelName)
                    .foregroundStyle(.primary)
                Text(modelID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}

// MARK: - Agent Picker Sheet

private struct AgentPickerSheet: View {
    let agents: [OpenCodeAgent]
    let selectedAgent: String?
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Built-in") {
                    ForEach(builtInAgents) { agent in agentRow(agent) }
                }
                let custom = customAgents
                if !custom.isEmpty {
                    Section("Custom") {
                        ForEach(custom) { agent in agentRow(agent) }
                    }
                }
            }
            .navigationTitle("Select Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func agentRow(_ agent: OpenCodeAgent) -> some View {
        Button {
            onSelect(agent.name)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name.capitalized)
                        .foregroundStyle(.primary)
                    if let description = agent.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedAgent == agent.name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private var builtInAgents: [OpenCodeAgent] {
        agents.filter(\.builtIn)
    }

    private var customAgents: [OpenCodeAgent] {
        agents.filter { !$0.builtIn }
    }
}

// MARK: - OpenCodeSession: Hashable for NavigationDestination

extension OpenCodeSession: Hashable {
    static func == (lhs: OpenCodeSession, rhs: OpenCodeSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
