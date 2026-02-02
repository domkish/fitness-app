//
//  BlockCardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI

struct BlockCardView: View {
    @ObservedObject var blockItem: SessionBlockItem
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Circuit: \(blockItem.block.workoutBlockId)")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.muted)

            ForEach(blockItem.exercises) { ex in
                ExerciseCardView(exItem: ex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

