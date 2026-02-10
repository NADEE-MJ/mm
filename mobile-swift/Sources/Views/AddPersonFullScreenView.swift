import SwiftUI

// MARK: - Add Person Full-Screen Flow

struct AddPersonFullScreenView: View {
    let onAdded: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var name = ""
    @State private var isTrusted = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Recommender Name", text: $name)

                    Toggle("Trusted Recommender", isOn: $isTrusted)
                }

                Section("Preview") {
                    LabeledContent("Name") {
                        Text(name.isEmpty ? "New Person" : name)
                    }
                    LabeledContent("Type") {
                        Text(isTrusted ? "Trusted" : "Recommender")
                    }
                }
            }
            .navigationTitle("Add Recommender")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }

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
