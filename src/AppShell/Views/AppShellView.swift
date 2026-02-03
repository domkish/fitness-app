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
        ZStack(alignment: .bottom) {
            // Main TabView
            TabView(selection: $selectedTab) {
                DashboardView(coordinator: coordinator)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                CalendarView(coordinator: coordinator)
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(Tab.calendar)

                TaskView(coordinator: coordinator)
                    .tabItem { Label("Tasks", systemImage: "checklist") }
                    .tag(Tab.tasks)

                RoutinesContainerView(coordinator: coordinator)
                    .tabItem { Label("Routines", systemImage: "figure.strengthtraining.traditional") }
                    .tag(Tab.routines)

                ProfileView(coordinator: coordinator)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(Tab.profile)
            }
            .onChange(of: selectedTab) { _, newValue in
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
                switch newStep {
                case .dashboard: selectedTab = .home
                case .calendar: selectedTab = .calendar
                case .task: selectedTab = .tasks
                case .workout, .exercise: selectedTab = .routines
                case .profile, .profileEdit, .profilePassword: selectedTab = .profile
                case .premium: break
                }
            }

            // Preview Progress Bar pinned above TabView
            if let _ = themeManager.previewThemeKey {
                ProgressView(value: themeManager.previewTimeRemaining, total: 10)
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.currentTheme.primary))
                    .frame(height: 4)
                    .padding(.horizontal)
                    .animation(.linear(duration: 0.1), value: themeManager.previewTimeRemaining)
                    .transition(.opacity)
                    .zIndex(1) // make sure it sits above the TabView
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

