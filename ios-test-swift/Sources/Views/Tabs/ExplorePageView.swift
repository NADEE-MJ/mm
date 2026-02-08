import SwiftUI

// MARK: - Explore Page
// Features: searchable, language filter chips, grid/list toggle,
// long-press context menu with peek preview, repo detail navigation.

struct ExplorePageView: View {
    @State private var repos = DemoData.repositories
    @State private var searchText = ""
    @State private var selectedLanguage: String?
    @State private var isGridView = false
    @Environment(ScrollState.self) private var scrollState

    private var languages: [String] {
        Array(Set(repos.map(\.language))).sorted()
    }

    private var filteredRepos: [RepoItem] {
        var result = repos
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let lang = selectedLanguage {
            result = result.filter { $0.language == lang }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    filterBar
                    countAndToggle

                    if filteredRepos.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Results",
                            subtitle: "Try a different search term or filter."
                        )
                    } else if isGridView {
                        gridContent
                    } else {
                        listContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y > 20
            } action: { _, isScrolled in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.isMinimized = isScrolled
                }
            }
            .background { PageBackground() }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search repositories…")
        }
    }

    // MARK: - Filter Chips

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedLanguage == nil) {
                    withAnimation { selectedLanguage = nil }
                }
                ForEach(languages, id: \.self) { lang in
                    FilterChip(title: lang, isSelected: selectedLanguage == lang) {
                        withAnimation { selectedLanguage = selectedLanguage == lang ? nil : lang }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    // MARK: - Count & Toggle

    private var countAndToggle: some View {
        HStack {
            Text("\(filteredRepos.count) repositories")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) { isGridView.toggle() }
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.selection, trigger: isGridView)
        }
    }

    // MARK: - Grid

    private var gridContent: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 155))], spacing: 12) {
            ForEach(filteredRepos) { repo in
                NavigationLink { RepoDetailView(repo: repo) } label: {
                    RepoGridCard(repo: repo)
                }
                .buttonStyle(.plain)
                .contextMenu { repoMenu(repo) } preview: { RepoPreview(repo: repo) }
            }
        }
    }

    // MARK: - List

    private var listContent: some View {
        ForEach(Array(filteredRepos.enumerated()), id: \.element.id) { index, repo in
            NavigationLink { RepoDetailView(repo: repo) } label: {
                RepoListRow(repo: repo)
            }
            .buttonStyle(.plain)
            .contextMenu { repoMenu(repo) } preview: { RepoPreview(repo: repo) }

            if index < filteredRepos.count - 1 {
                Rectangle().fill(AppTheme.stroke).frame(height: 1)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func repoMenu(_ repo: RepoItem) -> some View {
        Button { } label: { Label("Star", systemImage: "star") }
        Button { } label: { Label("Fork", systemImage: "tuningfork") }
        Button { } label: { Label("Copy URL", systemImage: "doc.on.doc") }
        ShareLink(item: "https://github.com/\(repo.owner)/\(repo.name)") {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.interactive() : .regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Grid Card

private struct RepoGridCard: View {
    let repo: RepoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.blue)

            Text(repo.name)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Text(repo.description)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: repo.languageColorHex))
                    .frame(width: 8, height: 8)
                Text(repo.language)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Label("\(repo.stars)", systemImage: "star")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - List Row

private struct RepoListRow: View {
    let repo: RepoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(repo.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(repo.lastUpdated)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Text(repo.description)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: repo.languageColorHex))
                        .frame(width: 9, height: 9)
                    Text(repo.language)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Label("\(repo.stars)", systemImage: "star")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Peek Preview (long-press)

private struct RepoPreview: View {
    let repo: RepoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(AppTheme.blue)
                Text(repo.owner)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("/")
                    .foregroundStyle(AppTheme.textTertiary)
                Text(repo.name)
                    .font(.subheadline.bold())
            }

            Text(repo.description)
                .font(.body)

            HStack(spacing: 16) {
                Label("\(repo.stars) stars", systemImage: "star.fill")
                Label(repo.language, systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)

            Text("Updated \(repo.lastUpdated)")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .frame(width: 320)
        .background(AppTheme.background)
    }
}

// MARK: - Repo Detail

private struct RepoDetailView: View {
    let repo: RepoItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.name).font(.title2.bold())
                        Text(repo.owner).foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }

                Text(repo.description).font(.body)

                // Stats
                FrostedCard {
                    HStack(spacing: 0) {
                        statCell(value: "\(repo.stars)", label: "Stars", icon: "star.fill")
                        statCell(value: "3", label: "Forks", icon: "tuningfork")
                        statCell(value: "2", label: "Issues", icon: "exclamationmark.circle")
                    }
                    .padding(.vertical, 12)
                }

                // Info rows
                FrostedCard {
                    VStack(spacing: 0) {
                        infoRow(icon: "chevron.left.forwardslash.chevron.right", label: "Language", value: repo.language)
                        DividerLine()
                        infoRow(icon: "clock", label: "Updated", value: repo.lastUpdated)
                        DividerLine()
                        infoRow(icon: "doc.text", label: "License", value: "MIT")
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button { } label: {
                        Label("Star", systemImage: "star").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(AppTheme.blue)

                    Button { } label: {
                        Label("Fork", systemImage: "tuningfork").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(AppTheme.blue)

                    ShareLink(item: "https://github.com/\(repo.owner)/\(repo.name)") {
                        Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(AppTheme.blue)
                }
            }
            .padding(16)
        }
        .background { PageBackground() }
        .navigationTitle(repo.name)
        .toolbarTitleDisplayMode(.inline)
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(AppTheme.blue)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.textTertiary).frame(width: 20)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
