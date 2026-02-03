//
//  SummaryBlockCardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/2/26.
//
import SwiftUI

struct SummaryBlockCardView: View {
    let block: SessionBlockItem

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            ForEach(block.exercises) { exercise in
                SummaryExerciseView(
                    exercise: exercise
                )
            }
        }
        .padding()
        .background(themeManager.currentTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

