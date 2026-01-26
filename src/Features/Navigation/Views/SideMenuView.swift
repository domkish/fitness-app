//
//  WorkoutRoutineView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var currentStep: AppShellStep
    @Binding var isMenuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)

            menuButton(
                "Dashboard",
                step: .dashboard,
                icon: "house",
                color: AppColors.textNav
            )

            menuButton(
                "Calendar",
                step: .calendar,
                icon: "calendar",
                color: AppColors.textNav
            )

            Spacer().frame(height: 20)
            
            menuButton(
                "Tasks",
                step: .task,
                icon: "checklist",
                color: AppColors.textNav
            )
            
            menuButton(
                "Exercises",
                step: .exercise,
                icon: "figure.strengthtraining.traditional",
                color: AppColors.textNav
            )

            menuButton(
                "Workout Routines",
                step: .workout,
                icon: "bolt",
                color: AppColors.textNav
            )

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.navSide)
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


