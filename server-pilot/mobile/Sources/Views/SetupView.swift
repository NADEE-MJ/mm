import SwiftUI

struct SetupView: View {
    @Bindable var authManager: AuthManager
    let networkService: NetworkService
    let deviceKeyManager: DeviceKeyManager

    @State private var code = ""
    @State private var deviceName = "iPhone"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enroll This Device")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Enrollment code", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))

                TextField("Device name", text: $deviceName)
                    .padding()
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    enroll()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Enroll")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.isEmpty || deviceName.isEmpty || isSubmitting)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
        }
    }

    private func enroll() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await networkService.enroll(code: code.lowercased(), deviceName: deviceName)
                await MainActor.run {
                    authManager.setDeviceId(response.deviceId)
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}
