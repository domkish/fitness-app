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
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject var authCoordinator: AuthCoordinator
    
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
                                    .fill(Color.primary)
                                    .frame(width: 25, height: 3)
                                    .cornerRadius(1.5)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
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
                            .foregroundColor(.primary)
                            .padding(6)
                            .background(.ultraThinMaterial)
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
            .environmentObject(themeManager)
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
                .environmentObject(authCoordinator)

        case .calendar:
            CalendarView(coordinator: coordinator)
                .environmentObject(authCoordinator)

        case .exercise:
            ExerciseView(coordinator: coordinator)
                .environmentObject(authCoordinator)

        case .workout:
            WorkoutView(coordinator: coordinator)
                .environmentObject(authCoordinator)

        case .session:
            SessionView(coordinator: coordinator)
                .environmentObject(authCoordinator)

        case .profile:
            ProfileView(coordinator: coordinator)
                .environmentObject(authCoordinator)
            
        case .profileEdit:
            ProfileEditView(coordinator: coordinator)
                .environmentObject(authCoordinator)
            
        case .profilePassword:
            ProfilePasswordView(coordinator: coordinator)
                .environmentObject(authCoordinator)
            
        case .profileTheme:
            ProfileThemeView(coordinator: coordinator)
                .environmentObject(authCoordinator)
            
        case .task:
            TaskView(coordinator: coordinator)
                .environmentObject(authCoordinator)
            
        case .premium:
            PremiumView(coordinator: coordinator)
                .environmentObject(authCoordinator)
        }
    }
}

