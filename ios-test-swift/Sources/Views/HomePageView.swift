import SwiftUI

struct HomePageView: View {
    @State private var query = ""
    @State private var showingQuickCapture = false
    @State private var favorites: Set<String> = []
    @State private var lastRefresh: Date = .now

    private var filteredSpotlight: [SpotlightCard] {
        guard !query.isEmpty else { return DemoData.spotlight }

        return DemoData.spotlight.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest Demo Surface")
                            .font(.title2.bold())
                        Text("A modern SwiftUI test shell with motion, search, and floating navigation.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Label("Updated \(lastRefresh, format: .dateTime.hour().minute())", systemImage: "clock")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showingQuickCapture = true
                            } label: {
                                Label("Quick Capture", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Spotlight") {
                    ForEach(filteredSpotlight) { card in
                        NavigationLink {
                            SpotlightDetailView(card: card)
                        } label: {
                            SpotlightRow(card: card, isFavorite: favorites.contains(card.id))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                toggleFavorite(for: card)
                            } label: {
                                Label(
                                    favorites.contains(card.id) ? "Unfavorite" : "Favorite",
                                    systemImage: favorites.contains(card.id) ? "heart.slash.fill" : "heart.fill"
                                )
                            }
                            .tint(.pink)
                        }
                        .contextMenu {
                            Button {
                                toggleFavorite(for: card)
                            } label: {
                                Label(
                                    favorites.contains(card.id) ? "Remove Favorite" : "Add Favorite",
                                    systemImage: "heart"
                                )
                            }
                            Button {
                                query = card.title
                            } label: {
                                Label("Search Similar", systemImage: "magnifyingglass")
                            }
                        }
                    }
                }

                Section("Quick Actions") {
                    ForEach(QuickAction.allCases, id: \.self) { action in
                        Label(action.title, systemImage: action.icon)
                            .font(.subheadline.weight(.medium))
                            .symbolEffect(.pulse, value: favorites.count)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Home")
            .searchable(text: $query, prompt: "Search features")
            .refreshable {
                await refreshData()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingQuickCapture = true
                    } label: {
                        Image(systemName: "square.and.pencil.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingQuickCapture) {
                QuickCaptureSheet()
                    .presentationDetents([.height(260), .medium])
                    .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.success, trigger: favorites.count)
        }
    }

    private func toggleFavorite(for card: SpotlightCard) {
        if favorites.contains(card.id) {
            favorites.remove(card.id)
        } else {
            favorites.insert(card.id)
        }
    }

    private func refreshData() async {
        try? await Task.sleep(for: .milliseconds(850))
        lastRefresh = .now
    }
}

private struct SpotlightRow: View {
    let card: SpotlightCard
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: card.accent.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: card.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.title)
                        .font(.headline)
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                }

                Text(card.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct SpotlightDetailView: View {
    let card: SpotlightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: card.accent.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
                .overlay {
                    Image(systemName: card.icon)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                }

            Text(card.title)
                .font(.largeTitle.bold())

            Text(card.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick Capture")
                    .font(.title3.bold())
                Text("Drop a note to test modern sheet interactions.")
                    .foregroundStyle(.secondary)

                TextField("Type a quick note...", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private enum QuickAction: CaseIterable {
    case startSession
    case scanLayout
    case exportSnapshot

    var title: String {
        switch self {
        case .startSession:
            return "Start Focus Session"
        case .scanLayout:
            return "Scan Floating Layout"
        case .exportSnapshot:
            return "Export Snapshot"
        }
    }

    var icon: String {
        switch self {
        case .startSession:
            return "play.circle.fill"
        case .scanLayout:
            return "sparkle.magnifyingglass"
        case .exportSnapshot:
            return "square.and.arrow.up.fill"
        }
    }
}
