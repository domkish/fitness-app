//
//  LoginViewModel.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }
    
    func login() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
