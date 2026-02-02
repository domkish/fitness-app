//
//  SetRowView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI
import Foundation

struct SetRowView: View {
    @ObservedObject var setItem: SessionSetItem
    @EnvironmentObject var themeManager: ThemeManager

    var onUserInteraction: (() -> Void)? = nil

    @State private var saveTask: Task<Void, Never>? = nil
    @State private var valueDigits: String = ""
    @State private var repsDigits: String = ""

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
            
            // Value input
            InputWithSuffixDecimal(
                title: nil,
                digits: $valueDigits,
                suffix: setItem.previousSet?.unit ?? "",
                maxValue: 999.9,
                decimal: true
            )
            .frame(maxWidth: 200)
            .onChange(of: valueDigits) { _ in
                onUserInteraction?()
                scheduleDebouncedSave()
            }

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
    }

    private func previousSetDisplay() -> String {
        guard let prev = setItem.previousSet,
              let reps = prev.completedReps,
              let value = prev.value,
              let unit = prev.unit else { return "-" }
        return "\(value)x\(reps) \(unit)"
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
        
        // Resolve unit: prefer previousSet?.unit, else fall back to last persisted set unit
        var unitToUse: String? = setItem.previousSet?.unit
        if unitToUse == nil {
            let setRepo = SessionSetRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let persistedSets = (try? setRepo.bySessionExercise(setItem.sessionExerciseId)) ?? []
            unitToUse = persistedSets.last?.unit
        }
        
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

