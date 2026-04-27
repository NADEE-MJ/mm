import SwiftUI

// MARK: - Add Person Full-Screen Flow

struct AddPersonFullScreenView: View {
    let onAdded: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var name = ""
    @State private var isTrusted = false
    @State private var selectedColorHex = PersonAppearance.defaultColorHex
    @State private var selectedEmoji: String? = PersonAppearance.emojiOptions.first
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Person name", text: $name)

                    Toggle("Trusted Person", isOn: $isTrusted)
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PersonAppearance.colorHexOptions, id: \.self) { option in
                                Button {
                                    selectedColorHex = option
                                } label: {
                                    Circle()
                                        .fill(PersonAppearance.color(from: option, isQuick: false))
                                        .frame(
                                            width: PersonAppearance.minimumControlSize,
                                            height: PersonAppearance.minimumControlSize
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedColorHex == option ? Color.accentColor : Color.clear,
                                                    lineWidth: 2
                                                )
                                                .padding(-4)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Circle())
                                .accessibilityLabel("Color \(PersonAppearance.colorName(for: option))")
                                .accessibilityAddTraits(selectedColorHex == option ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PersonAppearance.emojiOptions, id: \.self) { option in
                                Button {
                                    selectedEmoji = option
                                } label: {
                                    Text(option)
                                        .font(.title3)
                                        .frame(
                                            width: PersonAppearance.minimumControlSize,
                                            height: PersonAppearance.minimumControlSize
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedEmoji == option ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Emoji \(option)")
                                .accessibilityAddTraits(selectedEmoji == option ? .isSelected : [])
                            }

                            Button {
                                selectedEmoji = nil
                            } label: {
                                Text("None")
                                    .font(.caption.weight(.semibold))
                                    .frame(minWidth: PersonAppearance.minimumControlSize)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedEmoji == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("No emoji")
                            .accessibilityAddTraits(selectedEmoji == nil ? .isSelected : [])
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        PersonAvatarView(
                            name: name.isEmpty ? "New Person" : name,
                            emoji: selectedEmoji,
                            colorHex: selectedColorHex,
                            isQuick: false,
                            isTrusted: isTrusted,
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "New Person" : name)
                            Text(isTrusted ? "Trusted" : "Person")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

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
        let didAdd = await NetworkService.shared.addPerson(
            name: trimmed,
            isTrusted: isTrusted,
            color: selectedColorHex,
            emoji: selectedEmoji
        )
        if didAdd {
            _ = await MovieRepository.shared.syncPeople(force: true)
        }
        isSaving = false
        if didAdd {
            onAdded()
        }
    }
}

#Preview {
    AddPersonFullScreenView(onAdded: {})
}
