//
//  SetRowView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI
import Foundation
import GRDB

struct SetRowView: View {
    @ObservedObject var setItem: SessionSetItem
    @EnvironmentObject var themeManager: ThemeManager

    var onUserInteraction: (() -> Void)? = nil

    @State private var saveTask: Task<Void, Never>? = nil
    @State private var valueDigits: String = ""
    @State private var repsDigits: String = ""

    private enum Field: Hashable { case reps, value }
    @FocusState private var focusedField: Field?

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text("\(setItem.setNumber)")
                .frame(maxWidth: 40, alignment: .center)
                .foregroundColor(themeManager.currentTheme.textDefault)

            // Previous
            Text(previousSetDisplay())
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(themeManager.currentTheme.muted)
            
            // Value input
            InputWithSuffixDecimal(
                title: nil,
                digits: $valueDigits,
                suffix: "",
                maxValue: 999.9,
                decimal: true
            )
            .frame(maxWidth: 180)
            .onChange(of: valueDigits) { _ in
                onUserInteraction?()
                scheduleDebouncedSave()
            }
            .focused($focusedField, equals: .value)
            
            // Reps input
            InputWithSuffixDecimal(
                title: nil,
                digits: $repsDigits,
                suffix: "",
                maxValue: 100, // or your limit
                decimal: false
            )
            .frame(maxWidth: 60)
            .onChange(of: repsDigits) { _ in
                onUserInteraction?()
                scheduleDebouncedSave()
            }
            .focused($focusedField, equals: .reps)
            
            // Completed checkbox
            Button(action: {
                setItem.completed.toggle()
                onUserInteraction?()
                scheduleDebouncedSave()
            }) {
                Image(systemName: setItem.completed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(setItem.completed ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                    .contentShape(Rectangle())
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 24, alignment: .leading)
        }
        .padding(.vertical, 4)
        .onAppear {
            repsDigits = setItem.repsText.filter { $0.isNumber }
            valueDigits = setItem.valueText.filter { $0.isNumber }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CustomNumericKeyboardNext"))) { _ in
            switch focusedField {
            case .reps:
                focusedField = .value
            default:
                focusedField = nil
            }
        }
    }

    private func previousSetDisplay() -> String {
        // 1) Use any pre-wired previousSet if complete
        if let prev = setItem.previousSet,
           let reps = prev.completedReps,
           let value = prev.value {
            let valueText = String(format: "%.1f", value)
            return "\(valueText) x \(reps)"
        }

        // 2) Query storage for the last session's matching set for this exercise context
        // Fallback to dash on any failure
        guard let currentSetId = setItem.setId else { return "-" }

        do {
            let dbQueue = DatabaseQueueProvider.shared.dbQueue
            return try dbQueue.read { db in
                // Fetch the current set, exercise, block, and session to derive context
                guard
                    let currentSet = try SessionSetRecord.fetchOne(db, key: currentSetId),
                    currentSet.deletedAt == nil,
                    let exercise = try SessionExerciseRecord.fetchOne(db, key: currentSet.sessionExerciseId),
                    exercise.deletedAt == nil,
                    let block = try SessionBlockRecord.fetchOne(db, key: exercise.sessionBlockId),
                    block.deletedAt == nil,
                    let session = try SessionRecord.fetchOne(db, key: block.sessionId),
                    session.deletedAt == nil
                else {
                    return "-"
                }

                let targetExerciseId = exercise.exerciseId

                // Ensure we have a valid current session start date
                guard let currentStartedAt = session.startedAt else { return "-" }

                // Find the most recent prior session with same workout_id and started before current session, excluding soft-deleted
                var priorSessionQuery = SessionRecord
                    .filter(SessionRecord.Columns.deletedAt == nil)
                    .filter(SessionRecord.Columns.workoutId == session.workoutId)
                    .filter(sql: "started_at IS NOT NULL AND started_at < ?", arguments: [currentStartedAt])

                let priorSession = try priorSessionQuery
                    .order(SessionRecord.Columns.startedAt.desc)
                    .limit(1)
                    .fetchOne(db)

                guard let priorSessionUnwrapped = priorSession, let priorSessionId = priorSessionUnwrapped.id else {
                    return "-"
                }

                // Fetch all non-deleted blocks for the prior session
                let priorBlocks = try SessionBlockRecord
                    .filter(SessionBlockRecord.Columns.sessionId == priorSessionId)
                    .filter(SessionBlockRecord.Columns.deletedAt == nil)
                    .fetchAll(db)

                let blockIds = priorBlocks.compactMap { $0.id }
                guard !blockIds.isEmpty else { return "-" }

                // Find the prior session's exercise row that matches the same exercise_id and is not deleted
                let placeholders = blockIds.map { _ in "?" }.joined(separator: ",")
                var args = StatementArguments(blockIds)
                args += [targetExerciseId]

                let priorExercise = try SessionExerciseRecord
                    .filter(sql: "session_block_id IN (\(placeholders)) AND exercise_id = ? AND deleted_at IS NULL", arguments: args)
                    .order(SessionExerciseRecord.Columns.id.desc)
                    .fetchOne(db)

                guard let pExercise = priorExercise, let pExerciseId = pExercise.id else { return "-" }

                // In that prior exercise, fetch the non-deleted set with the same setNumber as current
                let matchingPriorSet = try SessionSetRecord
                    .filter(SessionSetRecord.Columns.sessionExerciseId == pExerciseId)
                    .filter(SessionSetRecord.Columns.setNumber == currentSet.setNumber)
                    .filter(SessionSetRecord.Columns.deletedAt == nil)
                    .order(SessionSetRecord.Columns.id.desc)
                    .fetchOne(db)

                guard let prev = matchingPriorSet,
                      let reps = prev.completedReps,
                      let value = prev.value else {
                    return "-"
                }
                let valueText = String(format: "%.1f", value)
                return "\(valueText) x \(reps)"
            }
        } catch {
            print("[SetRowView] previousSetDisplay error: \(error)")
            return "-"
        }
    }

    private func scheduleDebouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled {
                return
            }
            await saveNow()
        }
    }

    @MainActor
    private func saveNow() async {
        guard let setId = setItem.setId else { print("[SetRowView] saveNow() missing setId"); return }
        let repo = SessionSetRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        let reps = Int(repsDigits.trimmingCharacters(in: .whitespaces))
        let value: Double? = {
            let trimmed = valueDigits.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let raw = Double(trimmed) ?? 0
            return raw / 10.0
        }()
        
        let unitToUse: String? = nil
        
        do {
            try repo.updatePerformance(
                id: setId,
                completedReps: reps,
                value: value,
                unit: unitToUse,
                completed: setItem.completed
            )
            // Sync back display texts from digits
            setItem.repsText = repsDigits
            if valueDigits.isEmpty {
                setItem.valueText = ""
            } else {
                let v = (Double(valueDigits) ?? 0) / 10.0
                setItem.valueText = String(format: "%.1f", v)
            }
        } catch {
            print("[SetRowView] save error: \(error)")
        }
    }
}

