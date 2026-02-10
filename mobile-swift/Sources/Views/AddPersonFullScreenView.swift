import SwiftUI

// MARK: - Add Person Full-Screen Flow

struct AddPersonFullScreenView: View {
    let onAdded: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var name = ""
    @State private var isTrusted = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Person name", text: $name)

                    Toggle("Trusted Person", isOn: $isTrusted)
                }

                Section("Preview") {
                    LabeledContent("Name") {
                        Text(name.isEmpty ? "New Person" : name)
                    }
                    LabeledContent("Type") {
                        Text(isTrusted ? "Trusted" : "Person")
                    }
                }
            }
            .navigationTitle("Add Person")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
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
        let didAdd = await NetworkService.shared.addPerson(name: trimmed, isTrusted: isTrusted)
        isSaving = false
        if didAdd {
            onAdded()
        }
    }
}

#Preview {
    AddPersonFullScreenView(onAdded: {})
}
