import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.snappy(duration: 0.26, extraBounce: 0.04)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .semibold))

                            Text(tab.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedTab == tab ? AppTheme.textPrimary : AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.13))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.strongStroke, lineWidth: 1)
                                    )
                                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.strongStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 10)

            Button {
                // Reserved orb button to match GitHub-style floating utility control.
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle().stroke(AppTheme.strongStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
