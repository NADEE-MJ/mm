import SwiftUI

// MARK: - Community Page (Select / Multi-Select Screen)
// Features: EditMode with multi-select, add members via sheet,
// swipe actions (remove / promote), context menus, bulk actions toolbar,
// search, confirmation dialogs.
//
// NOTE: This view expects to be embedded in a parent NavigationStack
// (e.g. from a fullScreenCover). Do NOT add a NavigationStack here.

struct CommunityPageView: View {
    @State private var members = DemoData.communityMembers
    @State private var editMode: EditMode = .inactive
    @State private var selectedIds = Set<String>()
    @State private var showingAddMember = false
    @State private var showBulkDelete = false
    @State private var searchText = ""

    private var filteredMembers: [CommunityMember] {
        if searchText.isEmpty { return members }
        return members.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selectedIds) {
            if filteredMembers.isEmpty {
                ContentUnavailableView(
                    "No Members",
                    systemImage: "person.2.slash",
                    description: Text("Add some members to get started.")
                )
            } else {
                Section("\(filteredMembers.count) members") {
                    ForEach(filteredMembers) { member in
                        MemberRow(member: member)
                            .tag(member.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { removeMember(member) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { } label: {
                                    Label("Promote", systemImage: "arrow.up.circle")
                                }
                                .tint(.purple)

                                Button { } label: {
                                    Label("Message", systemImage: "envelope")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button { } label: { Label("View Profile", systemImage: "person") }
                                Button { } label: { Label("Send Message", systemImage: "envelope") }
                                Button { } label: { Label("Promote to Admin", systemImage: "crown") }
                                Divider()
                                Button(role: .destructive) { removeMember(member) } label: {
                                    Label("Remove from Community", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        let idsToDelete = offsets.map { filteredMembers[$0].id }
                        withAnimation { members.removeAll { idsToDelete.contains($0.id) } }
                    }
                    .onMove { from, to in
                        if searchText.isEmpty {
                            withAnimation { members.move(fromOffsets: from, toOffset: to) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { PageBackground() }
        .navigationTitle("Community")
        .searchable(text: $searchText, prompt: "Search members…")
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showingAddMember = true } label: {
                    Label("Add Member", systemImage: "person.badge.plus")
                }
            }

            // Bulk actions when selecting
            if editMode == .active && !selectedIds.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Remove Selected", role: .destructive) {
                            showBulkDelete = true
                        }
                        .foregroundStyle(.red)
                        Spacer()
                        Text("\(selectedIds.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddMemberSheet(members: $members)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .confirmationDialog(
            "Remove \(selectedIds.count) members?",
            isPresented: $showBulkDelete,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                withAnimation {
                    members.removeAll { selectedIds.contains($0.id) }
                    selectedIds.removeAll()
                    editMode = .inactive
                }
            }
        } message: {
            Text("This will remove the selected members from the community.")
        }
    }

    private func removeMember(_ member: CommunityMember) {
        withAnimation { members.removeAll { $0.id == member.id } }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: CommunityMember

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.avatar)
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(member.role)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Member Sheet

private struct AddMemberSheet: View {
    @Binding var members: [CommunityMember]
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedRole = "Developer"

    private let roles = ["Developer", "Designer", "Product Manager", "QA Engineer", "DevOps", "Data Scientist"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Full Name", text: $name)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                }

                Section("Preview") {
                    MemberRow(member: CommunityMember(
                        id: "preview",
                        name: name.isEmpty ? "New Member" : name,
                        role: selectedRole,
                        avatar: "person.circle.fill"
                    ))
                }
            }
            .navigationTitle("Add Member")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let member = CommunityMember(
                            id: UUID().uuidString,
                            name: name,
                            role: selectedRole,
                            avatar: "person.circle.fill"
                        )
                        withAnimation { members.append(member) }
                        dismiss()
                    }
                    .bold()
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
