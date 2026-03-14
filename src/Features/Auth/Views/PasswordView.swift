import SwiftUI

struct PasswordView: View {
    @EnvironmentObject var coordinator: AuthCoordinator
    @StateObject private var repo: LoginViewRepository
    @EnvironmentObject var themeManager: ThemeManager

    let onFinished: () -> Void

    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    init(onFinished: @escaping () -> Void = {}) {
        self.onFinished = onFinished
        _repo = StateObject(wrappedValue: LoginViewRepository())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.important.opacity(0.85),
                    themeManager.currentTheme.primary.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            BubblesOverlay()
                .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("SimplyFitness")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.currentTheme.surface)

                            Text("Create a secure password to finish setting up your account.")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.surface.opacity(0.9))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Set Password", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                SecureField("", text: $password)
                                    .themedPlaceholder(
                                        "Enter your password",
                                        when: password.isEmpty,
                                        color: themeManager.currentTheme.muted
                                    )
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding()
                                    .background(themeManager.currentTheme.formDefault)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Confirm Password", systemImage: "lock.shield")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                SecureField("", text: $confirmPassword)
                                    .themedPlaceholder(
                                        "Re-enter your password",
                                        when: confirmPassword.isEmpty,
                                        color: themeManager.currentTheme.muted
                                    )
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding()
                                    .background(themeManager.currentTheme.formDefault)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }

                            if let error = repo.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task {
                                    repo.errorMessage = nil

                                    guard validate() else { return }

                                    repo.isLoading = true
                                    defer { repo.isLoading = false }

                                    do {
                                        guard let email = coordinator.pendingEmail else {
                                            repo.errorMessage = "Missing email from reset flow."
                                            return
                                        }

                                        try await coordinator.submitPassword(
                                            email: email,
                                            password: password,
                                            confirm: confirmPassword
                                        )

                                        await MainActor.run {
                                            password = ""
                                            confirmPassword = ""
                                            coordinator.pendingEmail = nil
                                            coordinator.currentStep = .login
                                            onFinished()
                                        }
                                    } catch {
                                        repo.errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    if repo.isLoading {
                                        ProgressView()
                                    } else {
                                        Text("Set")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.currentTheme.important)
                            .controlSize(.large)
                            .disabled(repo.isLoading)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.currentTheme.surface)
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                        .padding(.horizontal)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func validate() -> Bool {
        guard !password.isEmpty else {
            repo.errorMessage = "Please enter a password."
            return false
        }

        guard !confirmPassword.isEmpty else {
            repo.errorMessage = "Please confirm your password."
            return false
        }

        guard password == confirmPassword else {
            repo.errorMessage = "Passwords do not match."
            return false
        }

        guard password.count >= 8 else {
            repo.errorMessage = "Password must be at least 8 characters long."
            return false
        }

        return true
    }
}
