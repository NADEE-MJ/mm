import SwiftUI

// MARK: - Add Person Full-Screen Flow

struct AddPersonFullScreenView: View {
    let onAdded: () -> Void

    @State private var name = ""
    @State private var isTrusted = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FrostedCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            TextField("Recommender Name", text: $name)
                                .textFieldStyle(.plain)
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(12)
                                .glassEffect(.regular, in: .rect(cornerRadius: 12))

                            Toggle(isOn: $isTrusted) {
                                HStack(spacing: 10) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(isTrusted ? .yellow : AppTheme.textTertiary)
                                    Text("Trusted Recommender")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .tint(AppTheme.blue)
                        }
                        .padding(14)
                    }

                    FrostedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isTrusted
                                                ? [.blue, .purple]
                                                : [AppTheme.surface, AppTheme.surfaceMuted],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Text(String((name.isEmpty ? "P" : name).prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name.isEmpty ? "New Person" : name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(isTrusted ? "Trusted recommender" : "Recommender")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background { PageBackground() }
            .navigationTitle("Add Recommender")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            await savePerson()
                        }
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func savePerson() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        await NetworkService.shared.updatePerson(name: trimmed, isTrusted: isTrusted)
        isSaving = false
        onAdded()
    }
}

#Preview {
    AddPersonFullScreenView(onAdded: {})
}
