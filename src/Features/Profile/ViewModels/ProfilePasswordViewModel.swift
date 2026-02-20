//
//  ProfilePasswordViewModel.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//
import Foundation
import Combine


final class ProfilePasswordViewModel: ObservableObject {
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    var canSave: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword
    }

    @MainActor
    func saveChanges() async {

        guard canSave else {
            errorMessage = "Passwords do not match or are empty."
            return
        }

        isSaving = true
        defer { isSaving = false }

        guard let token = TokenStore.token else {
            errorMessage = "Not authenticated"
            return
        }

        // 1️⃣ Debug-token request
        do {
            let debugURL = URL(string: "https://api.vsvault.io/api/auth/debug-token")!
            var debugRequest = URLRequest(url: debugURL)
            debugRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            debugRequest.httpMethod = "GET"

            let (debugData, _) = try await URLSession.shared.data(for: debugRequest)

            let debugJSON = try JSONSerialization.jsonObject(with: debugData) as? [String: Any]
            let valid = debugJSON?["valid"] as? Bool ?? false
            if !valid {
                errorMessage = "Authentication failed"
                return
            }

        } catch {
            errorMessage = "Authentication failed"
            return
        }

        // 2️⃣ Token valid → attempt password change
        do {
            try await authService.changePassword(
                current: currentPassword,
                new: newPassword,
                confirm: confirmPassword
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
