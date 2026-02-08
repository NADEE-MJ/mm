import SwiftUI

struct InboxPageView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header

                    Text("Inbox")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    FrostedCard {
                        ForEach(Array(DemoData.inboxThreads.enumerated()), id: \.element.id) { index, thread in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(thread.unreadCount > 0 ? AppTheme.blue : AppTheme.surfaceMuted)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 7)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(thread.title)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        if thread.unreadCount > 0 {
                                            Text("\(thread.unreadCount)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(AppTheme.blue, in: Capsule())
                                        }
                                    }
                                    Text(thread.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)

                            if index < DemoData.inboxThreads.count - 1 {
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

    private var header: some View {
        HStack {
            CircleIconButton(icon: "bell.badge") { }
            Spacer()
            CircleIconButton(icon: "line.3.horizontal.decrease.circle") { }
        }
    }
}
