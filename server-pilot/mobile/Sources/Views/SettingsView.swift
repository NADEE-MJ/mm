import SwiftUI

struct SettingsView: View {
    @Bindable var authManager: AuthManager

    var body: some View {
        Form {
            Section("Device") {
                LabeledContent("Device ID", value: authManager.deviceId ?? "Not enrolled")

                Button(role: .destructive) {
                    authManager.clearEnrollment()
                } label: {
                    Text("Clear Enrollment")
                }
            }

            Section("Network") {
                Text(AppConfiguration.apiBaseURL.absoluteString)
                    .font(.footnote.monospaced())
            }
        }
        .navigationTitle("Settings")
    }
}
