import SwiftUI

struct RootTabHostView: View {
    @Namespace private var tabPillNamespace
    @State private var selectedTab: TabItem = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackgroundView()

            Group {
                switch selectedTab {
                case .home:
                    HomePageView()
                case .library:
                    LibraryPageView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 100)
            }

            FloatingTabBar(
                selectedTab: $selectedTab,
                namespace: tabPillNamespace
            )
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

private struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.88, green: 0.94, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.20))
                .frame(width: 340, height: 340)
                .offset(x: -120, y: -320)
                .blur(radius: 16)

            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: 260, height: 260)
                .offset(x: 130, y: 320)
                .blur(radius: 20)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    RootTabHostView()
}
