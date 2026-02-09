//
//  ProfileEditViewModel.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import Foundation
import Combine

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var name: String
    @Published var isImperial: Bool
    @Published var weight: Bool
    @Published var fat: Bool
    @Published var photo: Bool
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    private var authCoordinator: AuthCoordinator

    init(user: User, authCoordinator: AuthCoordinator) {
        self.name = user.name
        self.isImperial = user.isImperial
        self.weight = user.weight
        self.fat = user.fat
        self.photo = user.photo
        self.authCoordinator = authCoordinator
    }

    /// Update local user (isImperial + name)
    func saveChanges() {
        authCoordinator.updateCurrentUser(name: name, isImperial: isImperial, weight: weight, fat: fat, photo: photo)
    }

    /// Update backend (name only)
    @MainActor
    func saveChangesToServer() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await authCoordinator.updateProfileNameOnServer(name: name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Replace user after fetching from AuthCoordinator
    func replaceUser(_ user: User, authCoordinator: AuthCoordinator) {
        self.name = user.name
        self.isImperial = user.isImperial
        self.weight = user.weight
        self.fat = user.fat
        self.photo = user.photo
        self.authCoordinator = authCoordinator
    }
}

