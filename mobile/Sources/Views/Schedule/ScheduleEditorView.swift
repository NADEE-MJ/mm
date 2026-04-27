import SwiftUI

struct ScheduleEditorView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @State private var draftEntries: [WeeklyScheduleEntry] = []
    @State private var statusMessage: String?

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        List {
            ForEach(days.indices, id: \.self) { day in
                Section(days[day]) {
                    let dayEntries = draftEntries.filter { $0.dayOfWeek == day }
                    if dayEntries.isEmpty {
                        Text("No templates")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(dayEntries) { entry in
                        HStack {
                            Text(repository.templateName(for: entry.templateId))
                            Spacer()
                            Button(role: .destructive) {
                                draftEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    Menu("Add Template") {
                        ForEach(repository.templates) { template in
                            Button(template.name) {
                                draftEntries.append(
                                    WeeklyScheduleEntry(
                                        id: UUID().uuidString,
                                        dayOfWeek: day,
                                        templateId: template.id,
                                        lastModified: Date().timeIntervalSince1970
                                    )
                                )
                            }
                        }
                    }
                }
            }

            Section {
                Button("Save Schedule") {
                    Task {
                        await repository.updateSchedule(entries: draftEntries)
                        statusMessage = "Saved locally and syncing in background."
                    }
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appListContainer()
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await repository.syncNow(forceFull: false) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            draftEntries = repository.schedule
        }
    }
}
