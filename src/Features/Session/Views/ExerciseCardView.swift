//
//  ExerciseCardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI

struct ExerciseCardView: View {
    @ObservedObject var exItem: SessionExerciseItem
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exItem.exercise.exerciseName)
                .foregroundColor(themeManager.currentTheme.textDefault)
                .padding(.vertical)

            VStack(spacing: 8) {
                // Header centered container
                HStack(spacing: 8) {
                    Text("Set").frame(maxWidth: 40, alignment: .leading)
                    Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Reps").frame(maxWidth: 60, alignment: .leading)
                    Text("Value").frame(maxWidth: 200, alignment: .leading)
                    Text("").frame(maxWidth: 24, alignment: .leading)
                }
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textDefault)
                .frame(maxWidth: 600) // constrain table width

                // Rows centered container
                VStack(spacing: 6) {
                    ForEach(exItem.sets) { set in
                        SetRowView(setItem: set)
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        Button(action: { addSet() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                            }
                            .padding(2)
                            .foregroundColor(Color.white)
                            .background(themeManager.currentTheme.success)
                            .font(.system(size: 16, weight: .semibold))
                            .contentShape(Rectangle())
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.bottom)
                    .frame(maxWidth: 600)
                }
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 5)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.currentTheme.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }

    private func addSet() {
        guard let last = exItem.sets.last else { return }
        let repo = SessionSetRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        let now = Date()
        // Fetch the persisted last set to obtain its actual unit
        let persistedSets = (try? repo.bySessionExercise(last.sessionExerciseId)) ?? []
        let currentUnit = persistedSets.last?.unit
        // Build a new record copying from last's backing values
        let lastReps: Int? = Int(last.repsText)
        let lastValue: Double? = Double(last.valueText)
        var newRec = SessionSetRecord(
            id: nil,
            sessionExerciseId: last.sessionExerciseId,
            setNumber: last.setNumber + 1,
            completedReps: lastReps,
            value: lastValue,
            unit: currentUnit,
            completed: 0,
            deletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        do {
            let newId = try repo.create(&newRec)
            // Build a SessionSetItem for UI
            let newItem = SessionSetItem(set: newRec, previousSet: last.previousSet)
            // Update UI on main thread
            DispatchQueue.main.async {
                exItem.sets.append(newItem)
            }
        } catch {
            print("[ExerciseCardView] Failed to add set: \(error)")
        }
    }
}

