import SwiftUI

struct ProfilePageView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        CircleIconButton(icon: "gearshape") { }
                        CircleIconButton(icon: "square.and.arrow.up") { }
                    }

                    profileHeader

                    FrostedCard {
                        HStack(spacing: 10) {
                            Image(systemName: "face.smiling")
                            Text("Set your status")
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }

                    Text("CS Major studying currently at CSUF. Very interested in Machine Learning.")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("linkedin.com/in/nadeem-maida-29a4b11a1")
                            .foregroundStyle(AppTheme.blue)
                    }

                    HStack(spacing: 16) {
                        Label("6 followers", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("·")
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("8 following")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    FrostedCard {
                        ForEach(Array(DemoData.profileActions.enumerated()), id: \.element.id) { index, action in
                            NavigationLink {
                                ProfileActionDetailView(action: action)
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
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < DemoData.profileActions.count - 1 {
                                DividerLine()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .background { PageBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 68, height: 68)
                .overlay(
                    Text("NM")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
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
}

private struct ProfileActionDetailView: View {
    let action: ProfileAction

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: action.icon)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.blue)
            Text(action.title)
                .font(.title.bold())
            Text("Count: \(action.value)")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PageBackground() }
        .navigationTitle(action.title)
        .toolbarTitleDisplayMode(.inline)
    }
}
