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
    @State private var activeIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Circuit: \(blockItem.block.workoutBlockId)")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.muted)

            ForEach(Array(blockItem.exercises.enumerated()), id: \.element.id) { index, ex in
                ExerciseCardView(
                    exItem: ex,
                    isActive: index == activeIndex,
                    onCompleted: {
                        advanceToNextIncomplete(from: index)
                    },
                    onBecameActive: {
                        activeIndex = index
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { activeIndex = firstIncompleteIndex() }
    }

    private func firstIncompleteIndex() -> Int {
        for (idx, ex) in blockItem.exercises.enumerated() {
            if ex.exerciseCompleted == false { return idx }
        }
        return 0
    }
    private func advanceToNextIncomplete(from current: Int) {
        let total = blockItem.exercises.count
        guard total > 0 else { return }
        // Find the next incomplete after current
        if let next = (current+1..<total).first(where: { !blockItem.exercises[$0].exerciseCompleted }) {
            activeIndex = next
            return
        }
        // Otherwise, wrap to the first incomplete
        if let first = (0..<total).first(where: { !blockItem.exercises[$0].exerciseCompleted }) {
            activeIndex = first
            return
        }
        // All completed: keep activeIndex at last valid index
        activeIndex = min(current, max(0, total-1))
    }
}

