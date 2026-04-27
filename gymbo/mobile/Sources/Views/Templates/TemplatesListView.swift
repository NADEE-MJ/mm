import SwiftUI

struct TemplatesListView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @State private var templateToSchedule: WorkoutTemplate?
    @State private var errorMessage: String?

    private let dayOptions: [(label: String, index: Int)] = [
        ("Monday", 0),
        ("Tuesday", 1),
        ("Wednesday", 2),
        ("Thursday", 3),
        ("Friday", 4),
        ("Saturday", 5),
        ("Sunday", 6),
    ]

    var body: some View {
        List {
            ForEach(repository.templates) { template in
                NavigationLink {
                    TemplateDetailView(template: template)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name)
                        Text("\(template.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        templateToSchedule = template
                    } label: {
                        Label("Set Day", systemImage: "calendar.badge.plus")
                    }
                    .tint(AppTheme.gymboBlue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !template.isSystem {
                        Button(role: .destructive) {
                            Task {
                                do {
                                    try await repository.deleteTemplate(id: template.id)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .appListContainer()
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    TemplateBuilderView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Set Day",
            isPresented: Binding(
                get: { templateToSchedule != nil },
                set: { if !$0 { templateToSchedule = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let template = templateToSchedule {
                ForEach(dayOptions, id: \.index) { option in
                    Button(option.label) {
                        Task {
                            await repository.scheduleTemplate(templateId: template.id, dayOfWeek: option.index)
                            templateToSchedule = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                templateToSchedule = nil
            }
        }
        .alert("Template Action Failed", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { isPresented in
            if !isPresented { errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
    }
}
