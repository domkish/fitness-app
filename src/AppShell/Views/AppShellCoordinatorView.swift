//
//  CoordinatorView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct AppShellCoordinatorView: View {
    @StateObject var coordinator = AppShellCoordinator()

    var body: some View {
        VStack {
            switch coordinator.currentStep {
            case .task:
                TaskView(coordinator: coordinator)
            case .profile:
                ProfileView(coordinator: coordinator)
            case .profileEdit:
                ProfileEditView(coordinator: coordinator)
            case .profilePassword:
                ProfilePasswordView(coordinator: coordinator)
            case .dashboard:
                DashboardView(coordinator: coordinator)
            case .calendar:
                CalendarView(coordinator: coordinator)
            case .exercise:
                ExerciseView(coordinator: coordinator)
            case .workout:
                WorkoutView(coordinator: coordinator)
            case .premium:
                PremiumView(coordinator: coordinator)
            }
        }
    }
}
