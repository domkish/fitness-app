//
//  AuthViewModel.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: User?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func loadCurrentUser() async {
        do {
            currentUser = try await userRepository.fetchUser()
        } catch {
            currentUser = nil
        }
    }

    func logout() {
        do {
            try userRepository.deleteUser()
            currentUser = nil
        } catch {
            // handle/log error if you want
        }
    }
}

