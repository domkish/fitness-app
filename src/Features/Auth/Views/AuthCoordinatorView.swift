//
//  AuthCoordinatorView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct AuthCoordinatorView: View {
    @EnvironmentObject var coordinator: AuthCoordinator

    var body: some View {
        switch coordinator.currentStep {
        case .login:
            LoginView(coordinator: coordinator)
        case .register:
            RegisterView(coordinator: coordinator)
        case .resetPassword:
            ResetPasswordView(coordinator: coordinator)
        case .done:
            AppShellView()
        }
    }
}

