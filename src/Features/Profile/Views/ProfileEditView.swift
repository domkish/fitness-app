//
//  ProfileEdit.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import GRDB
import Combine

private enum AuthCoordinatorPlaceholder {
    static let shared: AuthCoordinator = {
        // This placeholder should never be used; it will be replaced in onAppear.
        // Construct a minimal, inert coordinator using the already-migrated shared dbQueue to avoid in-memory DBs.
        let db = DatabaseQueueProvider.shared.dbQueue
        let userRepo = UserRepository(dbQueue: db)
        let authService = AuthService(userRepository: userRepo)
        let coord = AuthCoordinator(authService: authService, userRepository: userRepo)
        return coord
    }()
}

struct ProfileEditView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ProfileEditViewModel

    // MARK: - Init
    init(coordinator: AppShellCoordinator) {
        self.coordinator = coordinator

        _viewModel = StateObject(
            wrappedValue: ProfileEditViewModel(
                user: User(
                    id: 0,
                    name: "",
                    email: "",
                    isPremium: false,
                    isImperial: true,
                    weight: true,
                    fat: true,
                    photo: true,
                    theme: "classic",
                    emailVerifiedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                authCoordinator: AuthCoordinatorPlaceholder.shared
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

                                    HStack(spacing: 0) {
                                        Button("Imperial") {
                                            viewModel.isImperial = true
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(viewModel.isImperial ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(viewModel.isImperial ? .white : themeManager.currentTheme.textDefault)

                                        Button("Metric") {
                                            viewModel.isImperial = false
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(!viewModel.isImperial ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(!viewModel.isImperial ? .white : themeManager.currentTheme.textDefault)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Display Weight Graph")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    
                                    HStack(spacing: 0) {
                                        Button("Show") {
                                            viewModel.weight = true
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(viewModel.weight ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(viewModel.weight ? .white : themeManager.currentTheme.textDefault)

                                        Button("Hide") {
                                            viewModel.weight = false
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(!viewModel.weight ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(!viewModel.weight ? .white : themeManager.currentTheme.textDefault)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Display Body Fat % Graph")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    
                                    HStack(spacing: 0) {
                                        Button("Show") {
                                            viewModel.fat = true
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(viewModel.fat ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(viewModel.fat ? .white : themeManager.currentTheme.textDefault)
                                        
                                        Button("Hide") {
                                            viewModel.fat = false
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(!viewModel.fat ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(!viewModel.fat ? .white : themeManager.currentTheme.textDefault)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Display Photo Progress Map")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    
                                    HStack(spacing: 0) {
                                        Button("Show") {
                                            viewModel.photo = true
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(viewModel.photo ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(viewModel.photo ? .white : themeManager.currentTheme.textDefault)
                                        
                                        Button("Hide") {
                                            viewModel.photo = false
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(!viewModel.fat ? themeManager.currentTheme.primary : themeManager.currentTheme.primary.opacity(0.1))
                                        .foregroundColor(!viewModel.fat ? .white : themeManager.currentTheme.textDefault)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
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

