//
//  ResetPasswordViewModel.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import Foundation
import Combine

@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func resetPassword() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.resetPassword(email: email)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
