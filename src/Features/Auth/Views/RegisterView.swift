//
//  RegiserView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @StateObject private var repo: LoginViewRepository
    @EnvironmentObject var themeManager: ThemeManager
    @State private var didSubmitRegistration = false

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
        _repo = StateObject(wrappedValue: LoginViewRepository())
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    themeManager.currentTheme.important.opacity(0.85),
                    themeManager.currentTheme.primary.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle particles / bubbles overlay
            BubblesOverlay()
                .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 32) {
                        // App Branding
                        VStack(spacing: 8) {
                            Text("SimplyFitness")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.currentTheme.surface)
                            if !didSubmitRegistration {
                                Text("Thanks for downloading SimplyFitness! Please provide the email you'd like to use for your account")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.surface.opacity(0.9))
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Login Card
                        VStack(spacing: 16) {
                            if didSubmitRegistration {
                                VStack(spacing: 12) {
                                    Label("Check your email", systemImage: "envelope.badge")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textDefault)

                                    Text("Thanks, \(repo.name.isEmpty ? "there" : repo.name). We sent a confirmation to \(repo.email). Follow the instructions to finish setting up your account.")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.muted)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack {
                                        Button("Back to Login") {
                                            coordinator.goToLogin()
                                        }

                                        Spacer()
                                    }
                                    .font(.footnote)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Name", systemImage: "person")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.textDefault)

                                    TextField("", text: $repo.name)
                                        .themedPlaceholder("Your name", when: repo.name.isEmpty, color: themeManager.currentTheme.muted)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled(true)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .padding()
                                        .background(themeManager.currentTheme.formDefault)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                        )
                                        .cornerRadius(8)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Email", systemImage: "envelope")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.textDefault)

                                    TextField("", text: $repo.email)
                                        .themedPlaceholder("Your email address", when: repo.email.isEmpty, color: themeManager.currentTheme.muted)
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
                                            try await coordinator.register(
                                                email: repo.email,
                                                name: repo.name
                                            )
                                            didSubmitRegistration = true
                                        } catch {
                                            repo.errorMessage = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if repo.isLoading {
                                            ProgressView()
                                        } else {
                                            Text("Create Account")
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
                                    Button("Back to Login") {
                                        coordinator.goToLogin()
                                    }

                                    Spacer()
                                }
                                .font(.footnote)
                            }
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

