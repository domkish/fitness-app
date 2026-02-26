//
//  RegisterViewModel.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import Foundation
import Combine

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func register() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.register(email: email, name: name)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
