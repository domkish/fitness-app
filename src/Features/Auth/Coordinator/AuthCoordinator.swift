//
//  AuthCoordinator.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//
import SwiftUI
import Combine

@MainActor
final class AuthCoordinator: ObservableObject {

    @Published var currentStep: AuthStep = .login
    @Published var currentUser: User?

    let authService: AuthServicing
    let userRepository: UserRepository

    init(authService: AuthServicing, userRepository: UserRepository) {
        self.authService = authService
        self.userRepository = userRepository
        Task { await restoreSavedUser() }
    }

    // MARK: - Async Restore
    private func restoreSavedUser() async {
        do {
            // Require a valid token AND a non-system user
            if let token = TokenStore.token, !token.isEmpty,
               let savedUser = try await userRepository.fetchUser(),
               savedUser.id != 0 { // ignore system user
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
    func finishAuth() { currentStep = .done }

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

    func register(email: String, password: String) async {
        do {
            let user = try await authService.register(email: email, password: password)
            await MainActor.run {
                self.currentUser = user
                self.userRepository.setCurrentUserId(user.id)
                self.finishAuth()
            }
        } catch {
            print("Registration failed:", error.localizedDescription)
        }
    }

    func resetPassword(email: String) async {
        do {
            try await authService.resetPassword(email: email)
            await MainActor.run { goToLogin() }
        } catch {
            print("Reset password failed:", error.localizedDescription)
        }
    }

    // MARK: - Logout
    func logout() {
        // Purely local logout: do not modify SQLite or repository
        TokenStore.token = nil
        self.currentUser = nil
        self.goToLogin()
    }

    // MARK: - Profile Updates

    /// Update local user only (SQLite), keeps isImperial
    func updateCurrentUser(name: String, isImperial: Bool) {
        guard let user = currentUser else { return }

        let updatedUser = User(
            id: user.id,
            name: name,
            email: user.email,
            isPremium: user.isPremium,
            isImperial: isImperial, // local-only
            emailVerifiedAt: user.emailVerifiedAt,
            createdAt: user.createdAt,
            updatedAt: Date()
        )

        self.currentUser = updatedUser

        do {
            try userRepository.createOrUpdate(updatedUser) // ✅ repository
        } catch {
            print("Failed to persist user locally:", error)
        }
    }

    /// Update backend (name only) and merge with local isImperial
    func updateProfileNameOnServer(name: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.server(message: "No current user")
        }

        // Call backend with name only
        let updatedUser = try await authService.updateProfile(name: name)

        // Merge backend response with local-only isImperial
        let mergedUser = User(
            id: updatedUser.id,
            name: updatedUser.name,
            email: updatedUser.email,
            isPremium: updatedUser.isPremium,
            isImperial: currentUser.isImperial, // local-only
            emailVerifiedAt: updatedUser.emailVerifiedAt,
            createdAt: updatedUser.createdAt,
            updatedAt: updatedUser.updatedAt
        )

        // Update state & database
        self.currentUser = mergedUser
        try userRepository.createOrUpdate(mergedUser) // ✅ repository
    }
}

