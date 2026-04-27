import SwiftUI

struct AccountView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var repository = WorkoutRepository.shared
    @StateObject private var syncManager = SyncManager.shared

    @State private var unitPreference = "lbs"
    @State private var barbellWeight = "45"
    @State private var backupEnabled = false
    @State private var backupPayload = ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Text(authManager.currentUser?.email ?? "")
                    Text(authManager.currentUser?.username ?? "")

                    Picker("Unit", selection: $unitPreference) {
                        Text("lbs").tag("lbs")
                        Text("kg").tag("kg")
                    }

                    TextField("Barbell Weight", text: $barbellWeight)
                        .keyboardType(.decimalPad)

                    Button("Save Profile") {
                        Task {
                            guard let weight = Double(barbellWeight) else { return }
                            do {
                                try await authManager.updateProfile(unitPreference: unitPreference, barbellWeight: weight)
                                statusMessage = "Profile saved"
                            } catch {
                                statusMessage = "Failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }

                Section("Sync") {
                    Label(repository.isSyncing ? "Syncing now" : "Idle", systemImage: repository.isSyncing ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle")
                    Label(
                        repository.isUsingOfflineData ? "Offline mode active" : "Online",
                        systemImage: repository.isUsingOfflineData ? "wifi.slash" : "wifi"
                    )
                    Text("Queue worker: \(syncManager.isSyncing ? "Running" : "Idle")")
                    if let lastSyncAt = repository.lastSyncAt {
                        Text("Last sync: \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    Text("Queued changes: \(repository.pendingOperationsCount)")
                    if syncManager.unresolvedIssueCount > 0 {
                        Label(
                            "\(syncManager.unresolvedIssueCount) sync issue\(syncManager.unresolvedIssueCount == 1 ? "" : "s"), \(syncManager.conflictCount) conflict\(syncManager.conflictCount == 1 ? "" : "s")",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.yellow)
                    }

                    Button("Sync Now") {
                        Task { await repository.syncNow(forceFull: false) }
                    }

                    Button("Process Pending Queue") {
                        Task {
                            await repository.processPendingOperationsNow()
                            await repository.syncNow(forceFull: false)
                        }
                    }

                    NavigationLink {
                        SyncDiagnosticsView()
                    } label: {
                        Label("Open Sync Diagnostics", systemImage: "waveform.path.ecg")
                    }
                }

                Section("Backup") {
                    Toggle("Enable backup", isOn: $backupEnabled)
                        .onChange(of: backupEnabled) { _, newValue in
                            Task {
                                _ = try? await NetworkService.shared.updateBackupSettings(enabled: newValue)
                            }
                        }

                    Button("Export Backup") {
                        Task {
                            let payload = try? await NetworkService.shared.exportBackup()
                            backupPayload = String(describing: payload ?? [:])
                        }
                    }

                    TextEditor(text: $backupPayload)
                        .frame(minHeight: 120)
                }

                Section("Security") {
                    Button("Authenticate with Biometrics") {
                        BiometricAuthManager().authenticate()
                    }
                }

                if let statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authManager.logout()
                    }
                }
            }
            .navigationTitle("Account")
            .appFormContainer()
            .task {
                unitPreference = authManager.currentUser?.unitPreference ?? "lbs"
                barbellWeight = String(authManager.currentUser?.barbellWeight ?? 45)
                let settings = try? await NetworkService.shared.getBackupSettings()
                if let enabled = settings?["backup_enabled"]?.value as? Bool {
                    backupEnabled = enabled
                }
            }
        }
    }
}
