import SwiftUI

// MARK: - Account Page
// User account settings and information

struct AccountPageView: View {
    @State private var showingSettings = false
    @Environment(ScrollState.self) private var scrollState

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Movie Manager User")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("iOS App")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("App") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    
                    NavigationLink {
                        DevToolsView()
                    } label: {
                        Label("Developer Tools", systemImage: "hammer")
                    }
                }
                
                Section("Data") {
                    Button {
                        DatabaseManager.shared.clearAll()
                    } label: {
                        Label("Clear Local Cache", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(AppTheme.background)
            .navigationTitle("Account")
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    var body: some View {
        List {
            Section("Appearance") {
                Toggle("Dark Mode", isOn: .constant(true))
                    .disabled(true)
            }
            
            Section("Notifications") {
                Toggle("Push Notifications", isOn: .constant(false))
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.background)
        .navigationTitle("Settings")
    }
}

// MARK: - Dev Tools View

private struct DevToolsView: View {
    @State private var dbStats = ""
    @State private var wsConnected = false

    var body: some View {
        List {
            Section("Database") {
                Text(dbStats)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textSecondary)
                
                Button("Reload Stats") {
                    loadDBStats()
                }
            }
            
            Section("WebSocket") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(wsConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(wsConnected ? .green : .red)
                }
                
                Button(wsConnected ? "Disconnect" : "Connect") {
                    if wsConnected {
                        WebSocketManager.shared.disconnect()
                    } else {
                        WebSocketManager.shared.connect()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.background)
        .navigationTitle("Developer Tools")
        .onAppear {
            loadDBStats()
            wsConnected = WebSocketManager.shared.isConnected
        }
    }
    
    private func loadDBStats() {
        let db = DatabaseManager.shared
        dbStats = """
        Movies: \(db.movieCount)
        People: \(db.peopleCount)
        """
    }
}

#Preview {
    AccountPageView()
}
