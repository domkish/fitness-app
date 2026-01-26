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
    
    @State private var showThemes = false
    @State private var showPremium = false
    @State private var showUpgradeAlert = false
    
    var body: some View {
        let user = authCoordinator.currentUser!
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 70)
                    
                    // MARK: - User Info Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Profile Settings")
                            .font(.title)
                            .bold()
                                                
                        HStack {
                            Text("User:")
                                .foregroundColor(AppColors.textDefault)
                            Spacer()
                            Text("\(user.name)")
                                .bold()
                        }
                        HStack {
                            Text("Account Type:")
                                .foregroundColor(AppColors.textDefault)
                            Spacer()
                            if user.isPremium {
                                Text("Premium")
                                    .bold()
                            } else {
                                HStack(spacing: 5) {
                                    Text("Free")
                                        .bold()
                                    
                                    Button("(upgrade)") {
                                        showPremium = true
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Preferred Units:")
                                .foregroundColor(AppColors.textDefault)
                            Spacer()
                            Text(user.isImperial ? "Imperial" : "Metric")
                                .bold()
                        }
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // MARK: - Actions
                    VStack(spacing: 15) {
                        NavigationLink {
                            ProfileEditView(coordinator: coordinator)
                                .environmentObject(authCoordinator)
                        } label: {
                            HStack {
                                Text("Edit Profile")
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textDefault)
                            }
                            .padding()
                            .background(AppColors.surface)
                            .cornerRadius(12)
                        }
                        
                        NavigationLink {
                            ProfilePasswordView(coordinator: coordinator)
                                .environmentObject(authCoordinator)
                        } label: {
                            HStack {
                                Text("Change Password")
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textDefault)
                            }
                            .padding()
                            .background(AppColors.surface)
                            .cornerRadius(12)
                        }
                        
                        // MARK: - Themes Link (Premium Only)
                        Button {
                            if user.isPremium {
                                showThemes = true
                            } else {
                                showUpgradeAlert = true
                            }
                        } label: {
                            HStack {
                                Text("Themes")
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textDefault)
                            }
                            .padding()
                            .background(user.isPremium ? AppColors.surface : AppColors.surface.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .alert("Upgrade Required", isPresented: $showUpgradeAlert) {
                            Button("Cancel", role: .cancel) {}
                            Button("View Premium Benefits") {
                                showPremium = true
                            }
                        } message: {
                            Text("Themes are available for premium users only.")
                        }
                        
                        // Hidden NavigationLinks
                        .navigationDestination(isPresented: $showThemes) {
                            ProfileThemeView(coordinator: coordinator)
                                .environmentObject(authCoordinator)
                        }
                        .navigationDestination(isPresented: $showPremium) {
                            PremiumView(coordinator: coordinator)
                                .environmentObject(authCoordinator)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

