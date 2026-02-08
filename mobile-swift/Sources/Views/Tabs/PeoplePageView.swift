import SwiftUI

// MARK: - People Page
// Displays list of people and their trust status

struct PeoplePageView: View {
    @State private var people: [Person] = []
    @State private var searchText = ""
    @Environment(ScrollState.self) private var scrollState

    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPeople) { person in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("\(person.movieCount) movie\(person.movieCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Trust toggle
                        Button {
                            Task {
                                await NetworkService.shared.updatePerson(
                                    name: person.name,
                                    isTrusted: !person.isTrusted
                                )
                                await loadPeople()
                            }
                        } label: {
                            Image(systemName: person.isTrusted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(person.isTrusted ? .green : AppTheme.textTertiary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .background(AppTheme.background)
            .navigationTitle("People")
            .searchable(text: $searchText, prompt: "Search people")
            .refreshable {
                await loadPeople()
            }
            .task {
                await loadPeople()
            }
        }
    }

    private func loadPeople() async {
        await NetworkService.shared.fetchPeople()
        people = NetworkService.shared.people
    }
}

#Preview {
    PeoplePageView()
}
