//
//  SummaryExerciseView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/2/26.
//
import SwiftUI

struct SummaryExerciseView: View {
    let exercise: SessionExerciseItem

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header with PR badge
            HStack {
                Text(exercise.exercise.exerciseName)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textDefault)

                Spacer()
            }

            // Chart or single set summary
            if hasSingleSet, let summary = singleSetSummary {
                VStack(alignment: .center, spacing: 4) {
                    Text(summary.valueUnit)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.primary)
                    Text(summary.duration)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondary)
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            } else {
                
                // Total time formatted
                Text(formattedDurationLong(totalDuration))
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondary)
                
                SetsChartView(
                    points: chartPoints
                )
            }
        }
        .padding()
        .background(themeManager.currentTheme.background.opacity(0.5))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Computed properties

    private var totalDuration: Int {
        exercise.exercise.duration
    }

    private var isPR: Bool {
        exercise.sets.contains(where: { item in
            guard let prev = item.previousSet else { return false }
            guard
                let current = item.value,
                let previous = prev.value
            else { return false }
            return current > previous
        })
    }

    private var chartPoints: [SetsChartView.SetChartPoint] {
        exercise.sets.enumerated().flatMap { index, item in
            var points: [SetsChartView.SetChartPoint] = []

            // Current set
            if let value = item.value {
                points.append(
                    SetsChartView.SetChartPoint(
                        setIndex: index + 1,
                        value: value,
                        reps: item.reps,
                        unit: item.previousSet?.unit ?? "lbs",
                        isPrevious: false
                    )
                )
            }

            // Previous set
            if let prev = item.previousSet, let prevValue = prev.value {
                points.append(
                    SetsChartView.SetChartPoint(
                        setIndex: index + 1,
                        value: prevValue,
                        reps: prev.completedReps ?? 0,
                        unit: prev.unit ?? "lbs",
                        isPrevious: true
                    )
                )
            }

            return points
        }
    }

    // MARK: - Helpers
    private func formattedTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    private var hasSingleSet: Bool {
        exercise.sets.count == 1
    }

    private var singleSetSummary: (valueUnit: String, duration: String)? {
        guard let first = exercise.sets.first else { return nil }
        let unit = first.unit ?? exercise.exercise.unit ?? ""
        let valueText = first.valueText.trimmingCharacters(in: .whitespaces)
        let safeValue = valueText.isEmpty ? "0" : valueText
        let durationText = formattedDurationLong(exercise.exercise.duration)
        let valueUnit = (safeValue + " " + unit).trimmingCharacters(in: .whitespaces)
        return (valueUnit, durationText)
    }
}

// MARK: - Convenience extension for SessionSetItem
extension SessionSetItem {
    var value: Double? { Double(valueText) }
    var reps: Int { Int(repsText) ?? 0 }
}

