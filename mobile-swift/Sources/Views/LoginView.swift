import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @State private var authManager = AuthManager.shared
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localError: String?

    enum AuthMode: String, CaseIterable {
        case login = "Sign In"
        case register = "Create Account"
    }

    private var displayError: String? {
        localError ?? authManager.error
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    logo
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(AuthMode.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        localError = nil
                        authManager.clearError()
                    }
                }

                if let error = displayError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section(mode == .login ? "Sign In" : "Create Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                    if mode == .register {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                    }

                    SecureField("Password", text: $password)
                        .textContentType(.password)

                    if mode == .register {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.password)
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
                                Text(mode == .login ? "Sign In" : "Create Account")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(authManager.isLoading || !isFormValid)
                }

                Section {
                    Button(mode == .login ? "Need an account? Create one" : "Already have an account? Sign in") {
                        withAnimation(.spring(duration: 0.3)) {
                            mode = mode == .login ? .register : .login
                        }
                    }
                }
            }
            .navigationTitle("Movie Manager")
            .animation(.default, value: mode)
        }
    }

    private var logo: some View {
        VStack(spacing: 8) {
            Image(systemName: "film.stack")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
            Text("Track recommendations across devices")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty { return false }
        if mode == .register {
            if username.count < 3 { return false }
            if password.count < 6 { return false }
            if confirmPassword.isEmpty { return false }
        }
        return true
    }

    private func submit() {
        localError = nil
        authManager.clearError()

        if mode == .register {
            if password != confirmPassword {
                localError = "Passwords do not match"
                return
            }
            if password.count < 6 {
                localError = "Password must be at least 6 characters"
                return
            }
            if username.count < 3 {
                localError = "Username must be at least 3 characters"
                return
            }
            Task {
                _ = await authManager.register(
                    email: email,
                    username: username,
                    password: password
                )
            }
        } else {
            Task {
                _ = await authManager.login(email: email, password: password)
            }
        }
    }
}

#Preview {
    LoginView()
}
