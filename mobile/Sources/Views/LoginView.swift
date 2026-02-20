import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @State private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    logo
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                if let error = authManager.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Sign In") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.continue)
                        .onSubmit {
                            focusedField = .password
                        }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            if isFormValid {
                                submit()
                            }
                        }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if authManager.isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(authManager.isLoading || !isFormValid)
                } footer: {
                    Text("Accounts are provisioned by your admin.")
                }
            }
            .navigationTitle("Movie Manager")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                focusedField = .email
            }
        }
    }

    private var logo: some View {
        VStack(spacing: 8) {
            Image(systemName: "film.stack")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
            Text("Track movie recommendations across devices")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func submit() {
        authManager.clearError()
        Task {
            _ = await authManager.login(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
}
