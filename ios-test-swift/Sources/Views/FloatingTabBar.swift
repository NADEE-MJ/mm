import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.35, extraBounce: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .symbolEffect(.bounce, value: selectedTab)

                        if selectedTab == tab {
                            Text(tab.title)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, selectedTab == tab ? 18 : 14)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: tab.gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "activeTab", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .animation(.snappy(duration: 0.35, extraBounce: 0.15), value: selectedTab)
    }
}
