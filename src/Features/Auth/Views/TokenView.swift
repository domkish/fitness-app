//
//  TokenView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 3/13/26.
//

import SwiftUI

struct TokenView: View {
    @ObservedObject var coordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    let email: String
    let title: String
    let message: String
    let resendAction: () async throws -> Void
    let verifyAction: (_ token: String) async -> Bool
    let onVerified: () -> Void
    let onBack: () -> Void

    @StateObject private var repo = LoginViewRepository()
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.important.opacity(0.85),
                    themeManager.currentTheme.primary.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            BubblesOverlay()
                .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("SimplyFitness")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.currentTheme.surface)

                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.surface.opacity(0.9))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 16) {
                            VStack(spacing: 12) {
                                Label(title, systemImage: "lock.rectangle")
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.textDefault)

                                Text("Code sent to \(email)")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 8) {
                                    ForEach(0..<6, id: \.self) { idx in
                                        TextField("", text: Binding(
                                            get: { codeDigits[idx] },
                                            set: { newValue in
                                                handleDigitChange(newValue, at: idx)
                                            }
                                        ))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .font(.title2.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(themeManager.currentTheme.formDefault)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                                        )
                                        .cornerRadius(8)
                                        .focused($focusedIndex, equals: idx)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onAppear { focusedIndex = 0 }
                                .padding(.horizontal, 16)

                                if let error = repo.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }

                                if repo.isLoading {
                                    ProgressView()
                                        .padding(.top, 4)
                                }

                                HStack {
                                    Button("Back") {
                                        onBack()
                                    }

                                    Spacer()

                                    Button("Resend Token") {
                                        Task {
                                            await resendToken()
                                        }
                                    }
                                    .disabled(repo.isLoading)
                                }
                                .font(.footnote)
                                .padding(.horizontal)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.currentTheme.surface)
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                        .padding(.horizontal)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func handleDigitChange(_ newValue: String, at idx: Int) {
        let filtered = newValue.filter(\.isNumber)

        if filtered.isEmpty {
            codeDigits[idx] = ""
            return
        }

        codeDigits[idx] = String(filtered.suffix(1))

        if idx < 5 {
            focusedIndex = idx + 1
        } else {
            focusedIndex = nil
            Task {
                await verifyCodeIfComplete()
            }
        }
    }

    private func resendToken() async {
        repo.isLoading = true
        repo.errorMessage = nil
        defer { repo.isLoading = false }

        do {
            try await resendAction()
            codeDigits = Array(repeating: "", count: 6)
            focusedIndex = 0
        } catch {
            repo.errorMessage = error.localizedDescription
        }
    }

    private func verifyCodeIfComplete() async {
        let token = codeDigits.joined()
        guard token.count == 6 else { return }

        repo.isLoading = true
        repo.errorMessage = nil
        defer { repo.isLoading = false }

        let ok = await verifyAction(token)

        if ok {
            await MainActor.run {
                onVerified()
            }
        } else {
            await MainActor.run {
                repo.errorMessage = "Invalid token. Please try again."
                codeDigits = Array(repeating: "", count: 6)
                focusedIndex = 0
            }
        }
    }
}
