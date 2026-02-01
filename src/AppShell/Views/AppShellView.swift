import SwiftUI

struct AppShellView: View {
    @StateObject private var coordinator = AppShellCoordinator()
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    // Tab selection mapped to existing coordinator steps
    private enum Tab: Hashable {
        case home
        case calendar
        case tasks
        case routines
        case profile
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home (Dashboard)
            DashboardView(coordinator: coordinator)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            // Calendar
            CalendarView(coordinator: coordinator)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            // Tasks
            TaskView(coordinator: coordinator)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(Tab.tasks)

            // Routines (Workout Routines) – stable container to avoid root replacement
            RoutinesContainerView(coordinator: coordinator)
                .tabItem {
                    Label("Routines", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(Tab.routines)

            // Profile
            ProfileView(coordinator: coordinator)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(Tab.profile)
        }
        .onChange(of: selectedTab) { _, newValue in
            // Keep coordinator step in sync with selected tab
            switch newValue {
            case .home: coordinator.currentStep = .dashboard
            case .calendar: coordinator.currentStep = .calendar
            case .tasks: coordinator.currentStep = .task
            case .routines:
                if coordinator.currentStep != .exercise && coordinator.currentStep != .workout {
                    coordinator.currentStep = .workout
                }
            case .profile: coordinator.currentStep = .profile
            }
        }
        .onChange(of: coordinator.currentStep) { _, newStep in
            // Keep selected tab in sync if navigation occurs elsewhere
            switch newStep {
            case .dashboard: selectedTab = .home
            case .calendar: selectedTab = .calendar
            case .task: selectedTab = .tasks
            case .workout: selectedTab = .routines
            case .profileEdit, .profilePassword: selectedTab = .profile
            case .profile: selectedTab = .profile
            case .exercise: selectedTab = .routines
            case .premium: break // premium can present modally from within tabs as needed
            }
        }
    }
}

struct RoutinesContainerView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator
    var body: some View {
        Group {
            if coordinator.currentStep == .exercise {
                ExerciseView(coordinator: coordinator)
            } else {
                WorkoutView(coordinator: coordinator)
            }
        }
    }
}

