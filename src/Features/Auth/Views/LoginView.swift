//
//  LoginView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @StateObject private var repo: LoginViewRepository
    @EnvironmentObject var themeManager: ThemeManager

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
        _repo = StateObject(wrappedValue: LoginViewRepository())
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [themeManager.currentTheme.important.opacity(0.6), themeManager.currentTheme.primary.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 32) {
                        // App Branding
                        VStack(spacing: 8) {
                            Text("Fitness-App")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.currentTheme.surface)

                            Text("Welcome back. Let’s get you signed in.")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.surface.opacity(0.9))
                        }

                        // Login Card
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Email", systemImage: "envelope")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                TextField("", text: $repo.email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled(true)
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding()
                                    .background(themeManager.currentTheme.formDefault)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                    .onChange(of: repo.email) { newValue in
                                        repo.email = newValue.lowercased()
                                    }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Password", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                SecureField("••••••••", text: $repo.password)
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding()
                                    .background(themeManager.currentTheme.formDefault)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                    )
                            }

                            if let error = repo.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task {
                                    repo.isLoading = true
                                    repo.errorMessage = nil
                                    defer { repo.isLoading = false }
                                    do {
                                        try await coordinator.login(
                                            email: repo.email,
                                            password: repo.password
                                        )
                                    } catch {
                                        repo.errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    if repo.isLoading {
                                        ProgressView()
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.currentTheme.important)
                            .controlSize(.large)
                            .disabled(repo.isLoading)

                            Divider()

                            HStack {
                                Button("Create Account") {
                                    coordinator.goToRegister()
                                }

                                Spacer()

                                Button("Forgot Password?") {
                                    coordinator.goToResetPassword()
                                }
                            }
                            .font(.footnote)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.currentTheme.surface)
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                        .padding(.horizontal)
                    }
                    // Center content vertically if scroll content is smaller than screen
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
