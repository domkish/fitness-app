//
//  ProfileView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showThemes = false
    @State private var showPremium = false
    @State private var showUpgradeAlert = false
    
    var body: some View {
        if let user = authCoordinator.currentUser {
            ZStack {
                themeManager.currentTheme.background.ignoresSafeArea()

                    VStack() {
                        // MARK: - User Info Card
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Profile Settings")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                Spacer()
                                Button {
                                    authCoordinator.logout()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Log Out")
                                    }
                                    .font(.footnote)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(themeManager.currentTheme.surface)
                                    .cornerRadius(8)
                                }
                                .accessibilityLabel("Log out")
                            }

                            HStack(spacing: 8) {
                                Text("User:")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                Spacer()
                                Text("\(user.name)")
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                            }
                            HStack {
                                Text("Account Type:")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                Spacer()
                                if user.isPremium {
                                    Text("Premium")
                                        .bold()
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                } else {
                                    HStack(spacing: 5) {
                                        Text("Free")
                                            .bold()
                                            .foregroundColor(themeManager.currentTheme.textDefault)

                                        Button("(upgrade)") {
                                            showPremium = true
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.primary)
                                    }
                                }
                            }

                            HStack {
                                Text("Preferred Units:")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                Spacer()
                                Text(user.isImperial ? "Imperial" : "Metric")
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                            }
                        }
                        .padding()
                        .background(themeManager.currentTheme.surface)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

                        // MARK: - Actions
                        VStack(spacing: 15) {
                            NavigationLink {
                                ProfileEditView(coordinator: coordinator)
                                    .environmentObject(authCoordinator)
                                    .environmentObject(themeManager)
                            } label: {
                                HStack {
                                    Text("Edit Profile")
                                        .foregroundColor(themeManager.currentTheme.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                }
                                .padding()
                                .background(themeManager.currentTheme.surface)
                                .cornerRadius(12)
                            }

                            NavigationLink {
                                ProfilePasswordView(coordinator: coordinator)
                                    .environmentObject(authCoordinator)
                                    .environmentObject(themeManager)
                            } label: {
                                HStack {
                                    Text("Change Password")
                                        .foregroundColor(themeManager.currentTheme.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                }
                                .padding()
                                .background(themeManager.currentTheme.surface)
                                .cornerRadius(12)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Themes")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                }
                                let themes: [(key: String, title: String)] = [
                                    ("classic", "Classic"),
                                    ("midnight", "Midnight"),
                                    ("neon", "Neon"),
                                    ("luxury", "Luxury"),
                                    ("arctic", "Arctic"),
                                    ("sand", "Sand"),
                                    ("forest", "Forest"),
                                    ("gas", "Gas"),
                                    ("lipstick", "Lipstick")
                                ]
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                                    ForEach(themes, id: \.key) { item in
                                        let isSelected = (authCoordinator.currentUser?.theme.lowercased() == item.key)
                                        let swatchTheme = ThemeManager.resolve(item.key)
                                        Button {
                                            awaitSelectTheme(item.key)
                                        } label: {
                                            ZStack {
                                                // Two-color swatch using swatchTheme.primary & swatchTheme.surface
                                                // Base color (bottom-right)
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(swatchTheme.surface)

                                                // Diagonal overlay (top-left)
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(swatchTheme.primary)
                                                    .mask(DiagonalTriangle())
                                                VStack(spacing: 6) {
                                                    if isSelected {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(swatchTheme.textDefault)
                                                            .shadow(color: swatchTheme.surface.opacity(0.35), radius: 2, x: 0, y: 1)
                                                    }
                                                }
                                            }
                                            .frame(height: 60)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? Color.accentColor : swatchTheme.borderDefault, lineWidth: isSelected ? 2 : 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!(authCoordinator.currentUser?.isPremium ?? false) && item.key != (authCoordinator.currentUser?.theme.lowercased() ?? "classic"))
                                        .opacity(!(authCoordinator.currentUser?.isPremium ?? false) && item.key != (authCoordinator.currentUser?.theme.lowercased() ?? "classic") ? 0.5 : 1.0)
                                        .overlay(
                                            Group {
                                                if !(authCoordinator.currentUser?.isPremium ?? false) && item.key != (authCoordinator.currentUser?.theme.lowercased() ?? "classic") {
                                                    VStack {
                                                        Spacer()
                                                        Text("Premium")
                                                            .font(.caption2)
                                                            .padding(4)
                                                            .background(Color.black.opacity(0.5))
                                                            .foregroundColor(.white)
                                                            .clipShape(Capsule())
                                                            .padding(6)
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .padding()
                        }

                        Spacer()
                    }
                    .padding()
            }
        } else {
            // Lightweight placeholder when user is nil (e.g., during logout)
            VStack {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Signing out…")
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func awaitSelectTheme(_ key: String) {
        Task { await selectTheme(key) }
    }

    private func selectTheme(_ key: String) async {
        guard var user = authCoordinator.currentUser else { return }
        // If not premium and trying to select non-default, ignore
        if !user.isPremium && key.lowercased() != (user.theme.lowercased()) && key.lowercased() != "classic" { return }
        user = User(
            id: user.id,
            name: user.name,
            email: user.email,
            isPremium: user.isPremium,
            isImperial: user.isImperial,
            theme: key,
            emailVerifiedAt: user.emailVerifiedAt,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        await MainActor.run { authCoordinator.currentUser = user }
        do {
            try authCoordinator.userRepository.createOrUpdate(user)
            // Reassert current user id to preserve scoping for repositories after theme change
            authCoordinator.userRepository.setCurrentUserId(user.id)
        } catch {
            print("[ProfileView] Failed to persist theme:", error)
        }
        await MainActor.run { themeManager.update(for: user.theme) }
    }
}

struct DiagonalTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

