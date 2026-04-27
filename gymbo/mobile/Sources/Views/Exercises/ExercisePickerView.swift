import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Exercise) -> Void

    @StateObject private var repository = WorkoutRepository.shared

    var body: some View {
        NavigationStack {
            List(repository.exercises) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                        Text(weightTypeDisplayName(exercise.weightType))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .appListContainer()
            .navigationTitle("Pick Exercise")
        }
    }
}
