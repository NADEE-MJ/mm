import Foundation
import SwiftUI

private enum RepoFilter: String, CaseIterable, Identifiable {
    case type = "Type"
    case language = "Language"
    case sort = "Sort: Recently pushed"

    var id: String { rawValue }
}

struct ExplorePageView: View {
    @State private var selectedFilter: RepoFilter? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack {
                        CircleIconButton(icon: "chevron.left") { }
                        Spacer()
                        Text("Repositories")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        CircleIconButton(icon: "magnifyingglass") { }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RepoFilter.allCases) { filter in
                                Button {
                                    withAnimation(.spring(.smooth(duration: 0.25))) {
                                        selectedFilter = selectedFilter == filter ? nil : filter
                                    }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(
                                            selectedFilter == filter
                                                ? AppTheme.textPrimary
                                                : AppTheme.textSecondary
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(
                                    selectedFilter == filter
                                        ? .regular.interactive
                                        : .regular,
                                    in: Capsule()
                                )
                            }
                        }
                    }
                    .scrollClipDisabled()

                    ForEach(Array(DemoData.repositories.enumerated()), id: \.element.id) { index, repo in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(repo.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(repo.description)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Label("\(repo.stars)", systemImage: "star")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textTertiary)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: repo.languageColorHex))
                                        .frame(width: 9, height: 9)
                                    Text(repo.language)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 14)

                        if index < DemoData.repositories.count - 1 {
                            Rectangle()
                                .fill(AppTheme.stroke)
                                .frame(height: 1)
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

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
