import SwiftUI

// MARK: - Login View
// Sign In / Create Account with segmented picker.
// Matches the frontend AuthScreen design.

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
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Logo
                logo

                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .onChange(of: mode) { _, _ in
                    localError = nil
                    authManager.clearError()
                }

                // Error
                if let error = displayError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                // Form fields
                VStack(spacing: 16) {
                    fieldRow(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        keyboard: .emailAddress,
                        contentType: .emailAddress
                    )

                    if mode == .register {
                        fieldRow(
                            icon: "person.fill",
                            placeholder: "Username",
                            text: $username,
                            keyboard: .default,
                            contentType: .username
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    fieldRow(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        contentType: .password
                    )

                    if mode == .register {
                        fieldRow(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            isSecure: true,
                            contentType: .password
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                .animation(.spring(duration: 0.3), value: mode)

                // Submit button
                Button {
                    submit()
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(mode == .login ? "Sign In" : "Create Account")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.blue, in: .rect(cornerRadius: 14))
                }
                .disabled(authManager.isLoading || !isFormValid)
                .opacity(isFormValid ? 1 : 0.5)
                .padding(.horizontal, 24)

                // Footer
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        mode = mode == .login ? .register : .login
                    }
                } label: {
                    Group {
                        if mode == .login {
                            HStack(spacing: 0) {
                                Text("Don't have an account? ")
                                Text("Create one")
                                    .foregroundStyle(AppTheme.blue)
                                    .bold()
                            }
                        } else {
                            HStack(spacing: 0) {
                                Text("Already have an account? ")
                                Text("Sign in")
                                    .foregroundStyle(AppTheme.blue)
                                    .bold()
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()
            }
        }
        .scrollIndicators(.hidden)
        .background { PageBackground() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Logo

    private var logo: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 96, height: 96)
                .background(
                    LinearGradient(
                        colors: [AppTheme.blue.opacity(0.3), AppTheme.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 28)
                )

            Text("Movie Manager")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Track recommendations across devices")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Field Row

    private func fieldRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textContentType(contentType)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty { return false }
        if mode == .register {
            if username.count < 3 { return false }
            if password.count < 6 { return false }
            if confirmPassword.isEmpty { return false }
        }
        return true
    }

    // MARK: - Submit

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
