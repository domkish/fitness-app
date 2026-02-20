//
//  ProfilePassword.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI
import GRDB

struct ProfilePasswordView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel: ProfilePasswordViewModel
    @Environment(\.dismiss) private var dismiss

    init(coordinator: AppShellCoordinator) {
        self.coordinator = coordinator
        let db = DatabaseQueueProvider.shared.dbQueue
        let userRepo = UserRepository(dbQueue: db)
        let authService = AuthService(userRepository: userRepo)
        _viewModel = StateObject(wrappedValue: ProfilePasswordViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea() // Full-screen background

                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 30) {

                            // MARK: - Password Card
                            VStack(spacing: 20) {
                                Text("Change Password")
                                    .font(.title2)
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                // Password Fields
                                SecureFieldCard(title: "Current Password", text: $viewModel.currentPassword)
                                SecureFieldCard(title: "New Password", text: $viewModel.newPassword)
                                SecureFieldCard(title: "Confirm New Password", text: $viewModel.confirmPassword)

                                // Error Message
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 5)
                                }

                                // Change Password Button
                                Button {
                                    Task {
                                        await viewModel.saveChanges()
                                        if viewModel.errorMessage == nil { dismiss() }
                                    }
                                } label: {
                                    Text("Change Password")
                                        .bold()
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .background(viewModel.canSave ? themeManager.currentTheme.primary : Color.gray)
                                        .cornerRadius(14)
                                }
                                .disabled(!viewModel.canSave || viewModel.isSaving)
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

                            Spacer()
                        }
                        .padding()
                        // Full-height using GeometryReader
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }
            }
        }
    }
}

struct SecureFieldCard: View {
    let title: String
    @Binding var text: String
    @State private var isSecured: Bool = true
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(themeManager.currentTheme.textDefault)

            HStack {
                if isSecured {
                    SecureField(title, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity)
                        .textContentType(.password)
                        .padding()
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .background(themeManager.currentTheme.background)
                        .cornerRadius(12)
                } else {
                    TextField("", text: $text)
                        .themedPlaceholder(title, when: text.isEmpty, color: themeManager.currentTheme.muted)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity)
                        .textContentType(.password)
                        .padding()
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .background(themeManager.currentTheme.background)
                        .cornerRadius(12)
                }

                Button(action: { isSecured.toggle() }) {
                    Image(systemName: self.isSecured ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(themeManager.currentTheme.surface.opacity(0.9))
            .cornerRadius(12)
        }
    }
}

