import SwiftUI

struct RootTabHostView: View {
    @Namespace private var tabNamespace
    @State private var selectedTab: TabItem = .home

    var body: some View {
        ZStack {
            PageBackground()

            tabLayer(.home, HomePageView())
            tabLayer(.inbox, InboxPageView())
            tabLayer(.explore, ExplorePageView())
            tabLayer(.profile, ProfilePageView())
        }
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selectedTab: $selectedTab, namespace: tabNamespace)
                .padding(.top, 6)
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private func tabLayer<Content: View>(_ tab: TabItem, _ content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 112)
            }
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .animation(.easeInOut(duration: 0.16), value: selectedTab)
    }
}

#Preview {
    RootTabHostView()
}
