//
//  ResetPasswordView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct ResetPasswordView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @StateObject private var viewModel: ResetPasswordViewModel

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(
            wrappedValue: ResetPasswordViewModel(
                authService: coordinator.authService
            )
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Reset Password").font(.largeTitle).bold()

            TextField("Email", text: $viewModel.email)
                .autocorrectionDisabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }

            Button("Reset Password") {
                Task {
                    do {
                        try await viewModel.resetPassword()
                        coordinator.goToLogin()
                    } catch {}
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Back to Login") {
                coordinator.goToLogin()
            }

            Spacer()
        }
        .padding()
    }
}

