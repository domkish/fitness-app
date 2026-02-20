//
//  WorkoutRoutineView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var currentStep: AppShellStep
    @Binding var isMenuOpen: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)

            menuButton(
                "Dashboard",
                step: .dashboard,
                icon: "house",
                color: themeManager.currentTheme.textNav
            )

            menuButton(
                "Calendar",
                step: .calendar,
                icon: "calendar",
                color: themeManager.currentTheme.textNav
            )

            Spacer().frame(height: 20)
            
            menuButton(
                "Tasks",
                step: .task,
                icon: "checklist",
                color: themeManager.currentTheme.textNav
            )
            
            menuButton(
                "Exercises",
                step: .exercise,
                icon: "figure.strengthtraining.traditional",
                color: themeManager.currentTheme.textNav
            )

            menuButton(
                "Workout Routines",
                step: .workout,
                icon: "bolt",
                color: themeManager.currentTheme.textNav
            )

            Spacer()

            // Go Premium button pinned at bottom
            Button {
                withAnimation(.easeInOut) {
                    currentStep = .premium
                    isMenuOpen = false
                }
            } label: {
                let cornerRadius: CGFloat = 16
                let baseShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

                ZStack {
                    // Base shape fill (transparent) constrained to fixed height
                    baseShape
                        .fill(Color.clear)
                        .frame(height: 44)

                    // Corner-blended gradients layer (clipped to shape)
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: [themeManager.currentTheme.error, themeManager.currentTheme.error.opacity(0.0)]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                        RadialGradient(
                            gradient: Gradient(colors: [ themeManager.currentTheme.primary,  themeManager.currentTheme.primary.opacity(0.0)]),
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                        RadialGradient(
                            gradient: Gradient(colors: [themeManager.currentTheme.important, themeManager.currentTheme.important.opacity(0.0)]),
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    }
                    .clipShape(baseShape)
                    .frame(height: 44)
                    .compositingGroup()
                    .blendMode(.plusLighter)

                    // White border
                    baseShape
                        .stroke(themeManager.currentTheme.important, lineWidth: 2)
                        .frame(height: 44)

                    // Rainbow glow (soft per-color glows)
                    baseShape
                        .stroke(themeManager.currentTheme.pink.opacity(0.9), lineWidth: 2)
                        .frame(height: 44)
                        .shadow(color: themeManager.currentTheme.success.opacity(0.9), radius: 12)
                        .shadow(color: themeManager.currentTheme.error.opacity(0.9), radius: 12)
                        .shadow(color: themeManager.currentTheme.pink.opacity(0.9), radius: 12)
                    
                    // Content
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        Text("Go Premium")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(themeManager.currentTheme.navSide)
        .ignoresSafeArea()
    }

    private func menuButton(
        _ title: String,
        step: AppShellStep,
        icon: String,
        color: Color = .primary
    ) -> some View {
        Button {
            withAnimation(.easeInOut) {
                currentStep = step
                isMenuOpen = false
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
        }
    }
}

