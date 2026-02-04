//
//  RegiserView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @StateObject private var viewModel: RegisterViewModel

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(
            wrappedValue: RegisterViewModel(
                authService: coordinator.authService
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Register").font(.largeTitle).bold()

            TextField("Email", text: $viewModel.email)
                .autocorrectionDisabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }

            Button("Register") {
                Task {
                    do {
                        try await viewModel.register()
                        await coordinator.finishAuth()
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
