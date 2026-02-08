import SwiftUI

struct CommunityPageView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        CircleIconButton(icon: "magnifyingglass") { }
                    }

                    Text("Community")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    // MARK: - Organizations

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organizations")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        FrostedCard {
                            ForEach(["CSUF-ACM", "OpenSource-Club"], id: \.self) { org in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(AppTheme.surfaceMuted)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "building.2.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        )

                                    Text(org)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                        }
                    }

                    // MARK: - People

                    VStack(alignment: .leading, spacing: 12) {
                        Text("People")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        FrostedCard {
                            ForEach(
                                [
                                    ("You follow 8 people", "person.fill"),
                                    ("6 followers", "person.2.fill"),
                                ], id: \.0
                            ) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: item.1)
                                        .foregroundStyle(AppTheme.blue)
                                        .frame(width: 22)
                                    Text(item.0)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
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
}
