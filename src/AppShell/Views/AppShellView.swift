//
//  AppShellView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct AppShellView: View {
    @StateObject private var coordinator = AppShellCoordinator()
    @State private var isMenuOpen = false
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // Main content
                contentView
                    .frame(width: geo.size.width, height: geo.size.height)

                // Top-left controls (Hamburger + Profile)
                HStack {
                    // Hamburger (left)
                    Button {
                        withAnimation(.easeInOut) {
                            isMenuOpen.toggle()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(themeManager.currentTheme.textDefault)
                                    .frame(width: 25, height: 3)
                                    .cornerRadius(1.5)
                            }
                        }
                        .padding(8)
                    }

                    Spacer()

                    // Profile (right)
                    Button {
                        withAnimation(.easeInOut) {
                            isMenuOpen = false
                            coordinator.currentStep = .profile
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(6)
                            .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity) // 👈 this is key
                .padding(.top, geo.safeAreaInsets.top + 60)
                .padding(.horizontal, 20)

                // Dimmed background when menu is open
                if isMenuOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                isMenuOpen = false
                            }
                        }
                }

                // Side Menu
                SideMenuView(
                    currentStep: $coordinator.currentStep,
                    isMenuOpen: $isMenuOpen
                )
                .frame(width: geo.size.width * 0.75)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .offset(x: isMenuOpen ? 0 : -geo.size.width)
            }
            .animation(.easeInOut, value: isMenuOpen)
            .ignoresSafeArea()
            .onReceive(authCoordinator.$currentUser) {
                themeManager.update(for: $0?.theme)
            }
        }
    }

    // MARK: - Content Router
    @ViewBuilder
    private var contentView: some View {
        switch coordinator.currentStep {
        case .dashboard:
            DashboardView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

        case .calendar:
            CalendarView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

        case .exercise:
            ExerciseView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

        case .workout:
            WorkoutView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

        case .session:
            SessionView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

        case .profile:
            ProfileView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            
        case .profileEdit:
            ProfileEditView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            
        case .profilePassword:
            ProfilePasswordView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            
        case .task:
            TaskView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            
        case .premium:
            PremiumView(coordinator: coordinator)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
        }
    }
}

