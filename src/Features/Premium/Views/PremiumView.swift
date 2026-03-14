//
//  PremiumView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import StoreKit
import Foundation

struct PremiumView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var navigateToProfileAfterPurchase = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.important.opacity(0.85),
                        themeManager.currentTheme.primary.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Subtle particles / bubbles overlay
                BubblesOverlay()
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 24) {
                        // HERO
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(themeManager.currentTheme.surface.opacity(0.95))
                                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)

                                VStack(spacing: 14) {
                                    Text("SimplyFitness Premium")
                                        .font(.largeTitle.bold())
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .multilineTextAlignment(.center)

                                    Text("Own your fitness journey.")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.muted)

                                    // Price badge
                                    HStack(spacing: 8) {
                                        Text("$4.99")
                                            .font(.system(size: 34, weight: .bold, design: .rounded))
                                            .foregroundColor(themeManager.currentTheme.primary)
                                        Text("Lifetime access")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(themeManager.currentTheme.primary.opacity(0.12))
                                            )
                                    }
                                }
                                .padding(24)
                            }
                        }

                        // PREMIUM SUMMARY
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Premium includes")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            VStack(spacing: 12) {
                                BreakdownCard(title: "Performance & Workouts", items: [
                                    "Fully unlocked workout templates",
                                    "50 Schedulable recurring tasks",
                                    "Unlimited daily workout sessions",
                                    "Advanced routine scheduling",
                                    "All available themes"
                                ])
                            }
                        }

                        // CTA
                        VStack(spacing: 10) {
                            Button {
                                Task { await handlePurchaseTapped() }
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Unlock Premium for $4.99").fontWeight(.bold)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(themeManager.currentTheme.pink)
                                .foregroundColor(themeManager.currentTheme.surface)
                                .cornerRadius(14)
                                .shadow(color: themeManager.currentTheme.pink.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            Text("One-time purchase. Lifetime access.")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.surface)
                        }
                    }
                    .padding()
                    .onAppear {
                        if authCoordinator.currentUser?.isPremium == true {
                            coordinator.currentStep = .profile
                            dismiss()
                        }
                    }
                    .onReceive(purchaseManager.$didCompleteLifetimePurchase) { completed in
                        if completed {
                            coordinator.currentStep = .profile
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private extension PremiumView {
    func handlePurchaseTapped() async {
        do {
            // Perform local purchase first (non-blocking on server verification)
            guard let outcome = try await purchaseManager.purchasePremium() else {
                // User cancelled or pending
                return
            }

            // Immediately apply entitlement and navigate to Profile
            await applyPremiumEntitlement()
            await MainActor.run {
                coordinator.currentStep = .profile
                dismiss()
            }

            // Fire off server verification in the background (non-blocking)
            Task.detached {
                do {
                    let result = try await purchaseManager.verify(transactionId: outcome.transaction.id)
                    if !result.isPremium {
                        print("[PremiumView] Server verification indicates not premium; consider reconciling state.")
                    }
                } catch {
                    print("[PremiumView] Server verification failed: \(error)")
                }
            }
        } catch {
            if (error as NSError).code == 1 {
                // User cancelled
            } else {
                print("[PremiumView] Purchase failed: \(error)")
            }
        }
    }
    
    func applyPremiumEntitlement() async {
        guard var user = authCoordinator.currentUser else { return }
        if user.isPremium { return }
        user = User(
            id: user.id,
            name: user.name,
            email: user.email,
            isPremium: true,
            isImperial: user.isImperial,
            theme: user.theme,
            emailVerifiedAt: user.emailVerifiedAt,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        await MainActor.run {
            authCoordinator.currentUser = user
            do {
                try authCoordinator.userRepository.createOrUpdate(user)
                authCoordinator.userRepository.setCurrentUserId(user.id)
            } catch {
                print("[PremiumView] Failed to persist premium upgrade:", error)
            }
        }
    }

}

private struct BreakdownCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.surface)
                    Text(item)
                        .foregroundColor(themeManager.currentTheme.surface)
                        .font(.subheadline)
                }
            }
        }
    }
}

