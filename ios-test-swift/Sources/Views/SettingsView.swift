import SwiftUI

// MARK: - Settings View
// iOS Settings-style screen with grouped Form, toggles, pickers,
// sliders, navigation links, destructive actions, and alerts.

struct SettingsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("biometric") private var biometric = false
    @AppStorage("autoDownload") private var autoDownload = true
    @AppStorage("textSize") private var textSize = 16.0
    @AppStorage("accentColor") private var accentColor = "Blue"

    @State private var showClearCacheAlert = false
    @State private var showSignOutAlert = false
    @State private var showSignOutConfirmation = false
    @State private var cacheCleared = false

    var body: some View {
        Form {
            // ── Account ──
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text("NM")
                                .font(.headline)
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nadeem Maida").font(.headline)
                        Text("NADEE-MJ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink("Edit Profile") {
                    DetailView(title: "Edit Profile", icon: "person.fill")
                }
                NavigationLink("Manage Accounts") {
                    DetailView(title: "Manage Accounts", icon: "person.2.fill")
                }
            } header: {
                Text("Account")
            }

            // ── Notifications ──
            Section("Notifications") {
                Toggle("Push Notifications", isOn: $notifications)
                Toggle("Sounds", isOn: $sounds)
                Toggle("Haptic Feedback", isOn: $haptics)
            }

            // ── Appearance ──
            Section("Appearance") {
                Picker("Accent Color", selection: $accentColor) {
                    Text("Blue").tag("Blue")
                    Text("Purple").tag("Purple")
                    Text("Green").tag("Green")
                    Text("Orange").tag("Orange")
                    Text("Pink").tag("Pink")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Size: \(Int(textSize))pt")
                    Slider(value: $textSize, in: 12...28, step: 1)
                }

                Toggle("Auto-Download Media", isOn: $autoDownload)
            }

            // ── Privacy & Security ──
            Section("Privacy & Security") {
                Toggle("Face ID / Touch ID", isOn: $biometric)
                NavigationLink("Change Password") {
                    DetailView(title: "Change Password", icon: "lock.fill")
                }
                NavigationLink("Blocked Users") {
                    DetailView(title: "Blocked Users", icon: "person.slash.fill")
                }
                NavigationLink("Two-Factor Auth") {
                    DetailView(title: "Two-Factor Authentication", icon: "shield.lefthalf.filled")
                }
            }

            // ── Storage ──
            Section("Storage") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheCleared ? "0 MB" : "124 MB")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                Button("Clear Cache") {
                    showClearCacheAlert = true
                }
                .foregroundStyle(.red)
            }

            // ── About ──
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (Build 26)")
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Terms of Service") {
                    DetailView(title: "Terms of Service", icon: "doc.text")
                }
                NavigationLink("Privacy Policy") {
                    DetailView(title: "Privacy Policy", icon: "hand.raised.fill")
                }
                NavigationLink("Open-Source Licenses") {
                    DetailView(title: "Licenses", icon: "doc.plaintext")
                }
            }

            // ── Sign Out ──
            Section {
                Button("Sign Out") {
                    showSignOutConfirmation = true
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                withAnimation { cacheCleared = true }
            }
        } message: {
            Text("This will remove all cached images and data.")
        }
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to sign in again to use the app.")
        }
    }
}
