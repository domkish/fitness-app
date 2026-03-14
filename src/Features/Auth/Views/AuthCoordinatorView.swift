//
//  AuthCoordinatorView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//
import SwiftUI

struct AuthCoordinatorView: View {
    @EnvironmentObject var coordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        switch coordinator.currentStep {
        case .login:
            LoginView(coordinator: coordinator)

        case .register:
            RegisterView()

        case .resetPassword:
            ResetPasswordView(coordinator: coordinator)

        case .token:
            tokenView

        case .password:
            PasswordView()

        case .success:
            SuccessView()

        case .done:
            AppShellView()
        }
    }

    @ViewBuilder
    private var tokenView: some View {
        switch coordinator.tokenFlow {
        case .registration:
            TokenView(
                coordinator: coordinator,
                email: coordinator.pendingEmail ?? "",
                title: "Verify Email",
                message: "Enter the 6-digit code we sent to your email.",
                resendAction: {
                    guard let email = coordinator.pendingEmail else {
                        throw AuthError.server(message: "Missing email for token resend.")
                    }

                    // Reuse current registration method.
                    // If name is required by backend for resending, consider storing pendingName in coordinator too.
                    try await coordinator.register(email: email, name: "")
                },
                verifyAction: { token in
                    guard let email = coordinator.pendingEmail else { return false }
                    return await coordinator.verifyToken(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        token: token.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                },
                onVerified: {
                    coordinator.currentStep = .password
                },
                onBack: {
                    coordinator.currentStep = .register
                }
            )
            .environmentObject(themeManager)

        case .resetPassword:
            TokenView(
                coordinator: coordinator,
                email: coordinator.pendingEmail ?? "",
                title: "Reset Password",
                message: "Enter the 6-digit code we sent to your email.",
                resendAction: {
                    guard let email = coordinator.pendingEmail else {
                        throw AuthError.server(message: "Missing email for token resend.")
                    }
                    try await coordinator.resetPassword(email: email)
                },
                verifyAction: { token in
                    guard let email = coordinator.pendingEmail else { return false }
                    return await coordinator.verifyToken(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        token: token.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                },
                onVerified: {
                    coordinator.currentStep = .password
                },
                onBack: {
                    coordinator.currentStep = .resetPassword
                }
            )
            .environmentObject(themeManager)
        }
    }
}
