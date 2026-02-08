import SwiftUI

struct HomePageView: View {
    @State private var showingComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    topBar

                    Text("Home")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Work")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "ellipsis")
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        FrostedCard {
                            ForEach(Array(DemoData.workRows.enumerated()), id: \.element.id) { index, item in
                                NavigationLink {
                                    DetailStubView(title: item.title)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.icon)
                                            .foregroundStyle(AppTheme.blue)
                                            .frame(width: 22)
                                        Text(item.title)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                if index < DemoData.workRows.count - 1 {
                                    DividerLine()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Agents")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        FrostedCard {
                            NavigationLink {
                                DetailStubView(title: "Sessions")
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundStyle(Color.pink)
                                        .frame(width: 22)
                                    Text("Sessions")
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                try? await Task.sleep(for: .milliseconds(500))
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingComposer) {
                ComposeSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
                .frame(height: 36)
                .overlay {
                    HStack {
                        Circle()
                            .fill(AppTheme.blue)
                            .frame(width: 18, height: 18)
                        Text("Dynamic Island")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                }

            CircleIconButton(icon: "plus") { showingComposer = true }
            CircleIconButton(icon: "magnifyingglass") { }
        }
    }
}

private struct ComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("New conversation")
                    .font(.title3.weight(.bold))
                TextField("Ask Copilot", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.background)
        }
    }
}

private struct DetailStubView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.blue)
            Text(title)
                .font(.title.bold())
            Text("Demo detail page")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
