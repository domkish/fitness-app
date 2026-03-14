//
//  AuthCoordinator.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//
import SwiftUI
import Combine

enum TokenFlow {
    case registration
    case resetPassword
}

@MainActor
final class AuthCoordinator: ObservableObject {

    @Published var currentStep: AuthStep = .login
    @Published var pendingEmail: String?
    @Published var pendingName: String?
    @Published var tokenFlow: TokenFlow = .registration

    @Published var currentUser: User? {
        didSet {
            NotificationCenter.default.post(name: .userThemeDidChange, object: currentUser?.theme)
            userRepository.setCurrentUserId(currentUser?.id)
        }
    }

    let authService: AuthServicing
    let userRepository: UserRepository

    init(authService: AuthServicing, userRepository: UserRepository) {
        self.authService = authService
        self.userRepository = userRepository
        Task { await restoreSavedUser() }
        userRepository.diagnosticsLog("AuthCoordinator.init")
    }

    // MARK: - Async Restore
    private func restoreSavedUser() async {
        userRepository.diagnosticsLog("AuthCoordinator.restoreSavedUser")
        do {
            if let token = TokenStore.token,
               !token.isEmpty,
               let savedUser = try await userRepository.fetchUser(),
               savedUser.id != 0 {
                self.currentUser = savedUser
                self.currentStep = .done
                self.userRepository.setCurrentUserId(savedUser.id)
            } else {
                self.currentStep = .login
            }
        } catch {
            print("Failed to load saved user:", error)
            self.currentStep = .login
        }
    }

    // MARK: - Navigation
    func goToLogin() { currentStep = .login }
    func goToRegister() { currentStep = .register }
    func goToResetPassword() { currentStep = .resetPassword }
    func goToToken(flow: TokenFlow) {
        tokenFlow = flow
        currentStep = .token
    }
    func goToPassword() { currentStep = .password }
    func finishAuth() { currentStep = .done }
    func goToSuccess() { currentStep = .success }

    // MARK: - Actions
    func login(email: String, password: String) async {
        do {
            let user = try await authService.login(email: email, password: password)
            await MainActor.run {
                self.currentUser = user
                self.userRepository.setCurrentUserId(user.id)
                self.finishAuth()
            }
        } catch {
            print("Login failed:", error.localizedDescription)
        }
    }

    func register(email: String, name: String) async throws {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = try await authService.register(email: normalizedEmail, name: normalizedName)

            await MainActor.run {
                self.pendingEmail = result.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                self.pendingName = normalizedName
                self.tokenFlow = .registration
            }
        } catch {
            print("Registration failed:", error.localizedDescription)
            throw error
        }
    }

    func resendRegistrationToken() async throws {
        guard let email = pendingEmail, !email.isEmpty else {
            throw AuthError.server(message: "Missing email for token resend.")
        }

        guard let name = pendingName, !name.isEmpty else {
            throw AuthError.server(message: "Missing name for token resend.")
        }

        try await register(email: email, name: name)
    }

    func resetPassword(email: String) async throws {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            try await authService.resetPassword(email: normalizedEmail)

            await MainActor.run {
                self.pendingEmail = normalizedEmail
                self.tokenFlow = .resetPassword
            }
        } catch {
            print("Reset password failed:", error.localizedDescription)
            throw error
        }
    }

    func verifyToken(email: String, token: String) async -> Bool {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let ok = try await authService.verifyToken(email: normalizedEmail, token: normalizedToken)

            if ok {
                await MainActor.run {
                    self.pendingEmail = normalizedEmail
                }
            }

            return ok
        } catch {
            print("Verify token failed:", error.localizedDescription)
            return false
        }
    }

    func submitPassword(email: String, password: String, confirm: String) async throws {
        try await authService.setPassword(email: email, new: password, confirm: confirm)

        await MainActor.run {
            self.pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            self.pendingName = nil
            self.goToLogin()
        }
    }

    // MARK: - Logout
    func logout() {
        TokenStore.token = nil
        self.currentUser = nil
        self.pendingEmail = nil
        self.pendingName = nil
        self.tokenFlow = .registration
        self.goToLogin()
    }

    func updateTheme(using themeManager: ThemeManager) {
        themeManager.update(for: currentUser?.theme)
    }

    // MARK: - Profile Updates

    func updateCurrentUser(name: String, isImperial: Bool, weight: Bool, fat: Bool, photo: Bool) {
        guard let user = currentUser else { return }

        let updatedUser = User(
            id: user.id,
            name: name,
            email: user.email,
            isPremium: user.isPremium,
            isImperial: isImperial,
            weight: weight,
            fat: fat,
            photo: photo,
            theme: user.theme,
            emailVerifiedAt: user.emailVerifiedAt,
            createdAt: user.createdAt,
            updatedAt: Date()
        )

        self.currentUser = updatedUser

        do {
            try userRepository.createOrUpdate(updatedUser)
        } catch {
            print("Failed to persist user locally:", error)
        }
    }

    func updateProfileNameOnServer(name: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.server(message: "No current user")
        }

        let updatedUser = try await authService.updateProfile(name: name)

        let mergedUser = User(
            id: updatedUser.id,
            name: updatedUser.name,
            email: updatedUser.email,
            isPremium: updatedUser.isPremium,
            isImperial: currentUser.isImperial,
            weight: currentUser.weight,
            fat: currentUser.fat,
            photo: currentUser.photo,
            theme: currentUser.theme,
            emailVerifiedAt: updatedUser.emailVerifiedAt,
            createdAt: updatedUser.createdAt,
            updatedAt: updatedUser.updatedAt
        )

        self.currentUser = mergedUser
        try userRepository.createOrUpdate(mergedUser)
    }
}

extension Notification.Name {
    static let userThemeDidChange = Notification.Name("userThemeDidChange")
}
