//
//  AppShellCoordinator.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import Combine


final class AppShellCoordinator: ObservableObject {
    @Published var currentStep: AppShellStep = .dashboard
}

enum AppShellStep {
    case task
    case profile
    case profileEdit
    case profilePassword
    case premium
    case dashboard
    case calendar
    case exercise
    case workout
}
