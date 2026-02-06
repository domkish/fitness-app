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
            
            // Value input
            InputWithSuffixDecimal(
                title: nil,
                digits: $valueDigits,
                suffix: "",
                maxValue: 999.9,
                decimal: true
            )
            .frame(maxWidth: 200)
            .onChange(of: valueDigits) { _ in
                onUserInteraction?()
                scheduleDebouncedSave()
            }
            .focused($focusedField, equals: .value)

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
           let value = prev.value,
           let unit = prev.unit {
            let valueText = String(format: "%.1f", value)
            return "\(valueText) \(unit) x \(reps) reps"
        }

        // 2) Query storage for the last session's matching set for this exercise context
        // Fallback to dash on any failure
        guard let currentSetId = setItem.setId else { return "-" }

        // We'll walk relationships with lightweight inline queries to avoid broader refactors.
        // Expected schema records exist in the project: SessionSetRecord, SessionExerciseRecord, SessionBlockRecord, SessionRecord
        do {
            let dbQueue = DatabaseQueueProvider.shared.dbQueue
            return try dbQueue.read { db in
                // Fetch the current set, exercise, block, and session to derive context
                guard
                    let currentSet = try SessionSetRecord.fetchOne(db, key: currentSetId),
                    let exercise = try SessionExerciseRecord.fetchOne(db, key: currentSet.sessionExerciseId),
                    let block = try SessionBlockRecord.fetchOne(db, key: exercise.sessionBlockId),
                    let session = try SessionRecord.fetchOne(db, key: block.sessionId)
                else {
                    return "-"
                }

                let targetExerciseId = exercise.exerciseId

                // Find the most recent prior session by started_at
                let startedAtCol = SessionRecord.Columns.startedAt

                guard let currentStartedAt = session.startedAt else { return "-" }

                // Start with a SQL filter for the date comparison to avoid Column<Date?> vs Date mismatches
                var priorSessionQuery = SessionRecord
                    .filter(sql: "started_at < ?", arguments: [currentStartedAt])

                // Constrain to same workout id (updated from calendarWorkoutId to workoutId)
                priorSessionQuery = priorSessionQuery.filter(sql: "workout_id = ?", arguments: [session.workoutId])

                let priorSession = try priorSessionQuery
                    .order(startedAtCol.desc)
                    .limit(1)
                    .fetchOne(db)

                guard let priorSessionUnwrapped = priorSession, let priorSessionId = priorSessionUnwrapped.id else {
                    return "-"
                }

                // Find the prior session's exercise row that matches the same exercise_id
                // 1) Fetch all blocks for the prior session
                let priorBlocks = try SessionBlockRecord
                    .filter(sql: "session_id = ?", arguments: [priorSessionId])
                    .filter(sql: "deleted_at = ?", arguments: [nil])
                    .fetchAll(db)

                // 2) Find a session_exercise in those blocks with the same exercise_id
                let blockIds = priorBlocks.compactMap { $0.id }
                guard !blockIds.isEmpty else { return "-" }

                let placeholders = blockIds.map { _ in "?" }.joined(separator: ",")
                var args = StatementArguments(blockIds)
                args += [targetExerciseId]

                let priorExercise = try SessionExerciseRecord
                    .filter(sql: "session_block_id IN (\(placeholders)) AND exercise_id = ? AND deleted_at IS NULL", arguments: args)
                    .order(SessionExerciseRecord.Columns.id.desc)
                    .fetchOne(db)

                guard let pExercise = priorExercise, let pExerciseId = pExercise.id else { return "-" }

                // In that prior exercise, fetch the set with the same setNumber as current
                // let setNumberCol = SessionSetRecord.Columns.setNumber
                // let sesExIdCol = SessionSetRecord.Columns.sessionExerciseId

                let matchingPriorSet = try SessionSetRecord
                    .filter(SessionSetRecord.Columns.sessionExerciseId == pExerciseId)
                    .filter(SessionSetRecord.Columns.setNumber == currentSet.setNumber)
                    .filter(SessionSetRecord.Columns.deletedAt == nil)
                    .order(SessionSetRecord.Columns.setNumber.asc)
                    .fetchOne(db)

                guard let prev = matchingPriorSet,
                      let reps = prev.completedReps,
                      let value = prev.value else {
                    return "-"
                }
                let unit = prev.unit ?? (exercise.unit ?? "")
                let valueText = String(format: "%.1f", value)
                let unitText = unit.trimmingCharacters(in: .whitespaces)
                let unitPart = unitText.isEmpty ? "" : " \(unitText)"
                return "\(valueText)\(unitPart) x \(reps) reps"
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

