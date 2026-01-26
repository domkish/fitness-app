//
//  LoginView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @StateObject private var repo: LoginViewRepository

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
        _repo = StateObject(wrappedValue: LoginViewRepository())
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Login").font(.largeTitle).bold()

            TextField("Email", text: $repo.email)
                .autocorrectionDisabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $repo.password)
                .textFieldStyle(.roundedBorder)

            if let error = repo.errorMessage {
                Text(error).foregroundColor(.red)
            }

            Button {
                Task {
                    repo.isLoading = true
                    repo.errorMessage = nil
                    defer { repo.isLoading = false }
                    do {
                        try await coordinator.login(email: repo.email, password: repo.password)
                        // coordinator.login will set currentUser and move to .done
                    } catch {
                        repo.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                if repo.isLoading { ProgressView() }
                else { Text("Login").bold() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(repo.isLoading)

            HStack {
                Button("Register") { coordinator.goToRegister() }
                Spacer()
                Button("Forgot Password") { coordinator.goToResetPassword() }
            }
            .padding(.top)

            Spacer()
        }
        .padding()
    }
}
