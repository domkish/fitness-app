//
//  ResetPasswordView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//
import SwiftUI

struct ResetPasswordView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var repo = LoginViewRepository()

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
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

                            Text("Enter your account email to receive a 6-digit reset code.")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.surface.opacity(0.9))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Email", systemImage: "envelope")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                TextField("", text: $repo.email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .themedPlaceholder(
                                        "Your email address",
                                        when: repo.email.isEmpty,
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
                                Task { await sendCode() }
                            } label: {
                                HStack {
                                    if repo.isLoading { ProgressView() }
                                    Text(repo.isLoading ? "Sending…" : "Request Code")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.currentTheme.important)
                            .controlSize(.large)
                            .disabled(repo.isLoading || !isValidEmail(repo.email))
                            Divider()

                            HStack {
                                Button("Back to Login") {
                                    coordinator.goToLogin()
                                }

                                Spacer()
                            }
                            .font(.footnote)
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
    }

    private func sendCode() async {
        repo.errorMessage = nil

        let email = repo.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard isValidEmail(email) else {
            repo.errorMessage = "Please enter a valid email address."
            return
        }

        repo.isLoading = true
        defer { repo.isLoading = false }

        do {
            try await coordinator.resetPassword(email: email)
            coordinator.pendingEmail = email
            coordinator.currentStep = .token
        } catch {
            repo.errorMessage = error.localizedDescription
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("@") && trimmed.contains(".")
    }
}
