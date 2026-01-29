//
//  ProfileEdit.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import GRDB
import Combine

struct ProfileEditView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ProfileEditViewModel

    // MARK: - Init
    init(coordinator: AppShellCoordinator) {
        self.coordinator = coordinator
        // Temporary lightweight coordinator just to satisfy the initializer; real one provided via EnvironmentObject onAppear
        let tempDBQueue = try! DatabaseQueue() // in-memory
        let tempUserRepo = UserRepository(dbQueue: tempDBQueue)
        let tempAuthService = AuthService(userRepository: tempUserRepo)
        let tempAuthCoordinator = AuthCoordinator(authService: tempAuthService, userRepository: tempUserRepo)

        _viewModel = StateObject(
            wrappedValue: ProfileEditViewModel(
                user: User(
                    id: 0,
                    name: "",
                    email: "",
                    isPremium: false,
                    isImperial: false,
                    theme: "classic",
                    emailVerifiedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                authCoordinator: tempAuthCoordinator
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea() // Full-screen background

                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 30) {

                            // MARK: - Edit Profile Card
                            VStack(spacing: 25) {
                                Text("Edit Profile")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .foregroundColor(themeManager.currentTheme.textDefault)

                                    TextField("Your name", text: $viewModel.name)
                                        .padding()
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .background(themeManager.currentTheme.background)
                                        .cornerRadius(12)
                                }

                                // Preferred Units
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Preferred Units")
                                        .foregroundColor(themeManager.currentTheme.textDefault)

                                    Picker("Units", selection: $viewModel.isImperial) {
                                        Text("Metric").tag(false)
                                        Text("Imperial").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                // Save Button
                                Button {
                                    viewModel.saveChanges()
                                    Task { await viewModel.saveChangesToServer() }
                                    dismiss()
                                } label: {
                                    Text("Save Changes")
                                        .foregroundColor(.white)
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.currentTheme.primary)
                                        .cornerRadius(14)
                                }
                                .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

                            Spacer()
                        }
                        .padding()
                        // Use geometry size for full-height
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }
            }
        }
        .onAppear {
            if let currentUser = authCoordinator.currentUser {
                viewModel.replaceUser(currentUser, authCoordinator: authCoordinator)
            }
        }
    }
}

