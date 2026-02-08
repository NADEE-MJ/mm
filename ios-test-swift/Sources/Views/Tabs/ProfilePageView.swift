import SwiftUI

// MARK: - Profile Page
// Features: gradient avatar, set-status sheet, profile stats, navigation to Settings,
// action cards with navigation, share profile.

struct ProfilePageView: View {
    @State private var status = ""
    @State private var showingStatusSheet = false
    @Environment(ScrollState.self) private var scrollState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    profileHeader
                    statusCard
                    bioSection
                    statsSection
                    actionsCard
                    labsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                withAnimation(.spring(duration: 0.35)) {
                    scrollState.update(offset: offset)
                }
            }
            .background { PageBackground() }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: URL(string: "https://github.com/NADEE-MJ")!) {
                        Label("Share Profile", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingStatusSheet) {
                StatusSheet(status: $status)
                    .presentationDetents([.height(220)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .overlay(
                    Text("NM")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Nadeem Maida")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("NADEE-MJ")
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        Button { showingStatusSheet = true } label: {
            FrostedCard {
                HStack(spacing: 10) {
                    Image(systemName: status.isEmpty ? "face.smiling" : "face.smiling.fill")
                        .symbolEffect(.bounce, value: status)
                    Text(status.isEmpty ? "Set your status" : status)
                        .foregroundStyle(status.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "pencil")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bio

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CS Major studying currently at CSUF. Very interested in Machine Learning.")
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Text("linkedin.com/in/nadeem-maida")
                    .foregroundStyle(AppTheme.blue)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            Label("6 followers", systemImage: "person.2")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Text("·").foregroundStyle(AppTheme.textTertiary)
            Text("8 following")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Labs Card

    private var labsCard: some View {
        FrostedCard {
            NavigationLink {
                DevToolsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .frame(width: 22)
                        .foregroundStyle(.purple)
                    Text("Developer Labs")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("SQLite · API · WS")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(14)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        FrostedCard {
            ForEach(Array(DemoData.profileActions.enumerated()), id: \.element.id) { index, action in
                NavigationLink {
                    DetailView(title: action.title, icon: action.icon)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.icon)
                            .frame(width: 22)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(action.title)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(action.value)
                            .foregroundStyle(AppTheme.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(14)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if index < DemoData.profileActions.count - 1 {
                    DividerLine()
                }
            }
        }
    }
}

// MARK: - Status Sheet

private struct StatusSheet: View {
    @Binding var status: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("What's your status?", text: $status)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                HStack {
                    Button("Clear") {
                        status = ""
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    Spacer()
                    Button("Save") { dismiss() }
                        .bold()
                }

                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("Set Status")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
