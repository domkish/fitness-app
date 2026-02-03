//
//  ExerciseCardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
//
//  ExerciseCardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI
import Combine

struct ExerciseCardView: View {
    @ObservedObject var exItem: SessionExerciseItem
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    var isActive: Bool = false
    var onCompleted: (() -> Void)? = nil
    var onBecameActive: (() -> Void)? = nil

    @State private var elapsed: Int = 0
    @State private var lastTick: Date? = nil
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var noteSaveTask: Task<Void, Never>? = nil

    @State private var showingTimeEditor: Bool = false
    @State private var editHours: String = "00"
    @State private var editMinutes: String = "00"
    @State private var editSeconds: String = "00"
    @State private var showTimerInfo = false
    @State private var noteText: String = ""

    private var maxSetsAllowed: Int {
        if authCoordinator.currentUser?.isPremium == true { return 20 }
        return 5
    }

    var body: some View {
        ZStack {
            // Main card content
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(exItem.exercise.exerciseName)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Spacer()
                    HStack(spacing: 8) {
                        // Timer display button
                        Button(action: { showingTimeEditor.toggle() }) {
                            Text(formattedTime(elapsed))
                                .foregroundColor(exItem.exerciseCompleted
                                    ? themeManager.currentTheme.muted
                                    : themeManager.currentTheme.muted)
                        }
                        .buttonStyle(.plain)

                        // Info button
                        Button {
                            showTimerInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(themeManager.currentTheme.secondary)
                        }
                        .popover(isPresented: $showTimerInfo, arrowEdge: .bottom) {
                            ZStack {
                                themeManager.currentTheme.surface
                                    .ignoresSafeArea()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Editing the Timer")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Text("You can modify the exercise time once the exercise is marked as complete.")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                }
                                .padding()
                                .frame(maxWidth: 250)
                            }
                        }
                    }
                }
                .padding(.vertical)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                        )

                    GrowingTextEditor(text: $noteText, minLines: 1)
                        .foregroundColor(themeManager.currentTheme.muted)
                        .padding(8)
                        .onChange(of: noteText) { _ in
                            scheduleNoteDebouncedSave()
                        }

                    if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("notes…")
                            .font(.body)
                            .foregroundColor(themeManager.currentTheme.muted)
                            .background(themeManager.currentTheme.formDefault)
                            .padding(EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                            .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Set").frame(maxWidth: 40, alignment: .center)
                        Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Reps").frame(maxWidth: 60, alignment: .leading)
                        Text("Value").frame(maxWidth: 200, alignment: .leading)
                        Text("").frame(maxWidth: 24, alignment: .leading)
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .frame(maxWidth: 600)

                    VStack(spacing: 6) {
                        ForEach(exItem.sets) { set in
                            SetRowView(setItem: set, onUserInteraction: {
                                if exItem.exerciseCompleted {
                                    exItem.exerciseCompleted = false
                                    let repo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
                                    if let exId = exItem.exercise.id {
                                        try? repo.markCompleted(id: exId, completed: false)
                                    }
                                }
                                onBecameActive?()
                            })
                        }

                        HStack(spacing: 12) {
                            Button(action: { addSet() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add Set").bold()
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(themeManager.currentTheme.surface)
                                .foregroundColor(themeManager.currentTheme.secondary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(exItem.sets.count >= maxSetsAllowed)

                            Spacer(minLength: 0)

                            Button(action: {
                                exItem.exerciseCompleted.toggle()
                                let repo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
                                if let exId = exItem.exercise.id {
                                    try? repo.markCompleted(id: exId, completed: exItem.exerciseCompleted)
                                }
                                if exItem.exerciseCompleted == false { onBecameActive?() }
                                if exItem.exerciseCompleted { onCompleted?() }
                            }) {
                                HStack(spacing: 8) {
                                    Text(exItem.exerciseCompleted ? "Completed" : "Complete")
                                        .bold()
                                    Image(systemName: exItem.exerciseCompleted ? "checkmark.square.fill" : "square")
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(exItem.exerciseCompleted ? themeManager.currentTheme.primary.opacity(0.15) : themeManager.currentTheme.secondary)
                                )
                                .foregroundColor(exItem.exerciseCompleted ? themeManager.currentTheme.primary : themeManager.currentTheme.background)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(exItem.exerciseCompleted ? "Completed" : "Complete")
                    }
                    .frame(maxWidth: 600)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 5)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                exItem.exerciseCompleted
                    ? themeManager.currentTheme.primary.opacity(0.2)
                    : themeManager.currentTheme.surface
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive && !exItem.exerciseCompleted ? themeManager.currentTheme.primary.opacity(0.4) : Color.clear,
                        lineWidth: isActive && !exItem.exerciseCompleted ? 2 : 0
                    )
                    .shadow(color: isActive && !exItem.exerciseCompleted ? themeManager.currentTheme.primary.opacity(0.65) : Color.clear, radius: 8)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
            .onAppear {
                elapsed = exItem.exercise.duration
                noteText = exItem.exercise.note ?? ""
                if isActive && !exItem.exerciseCompleted {
                    lastTick = Date()
                }
            }
            .onChange(of: isActive) { newVal in
                if newVal && !exItem.exerciseCompleted {
                    lastTick = Date()
                } else {
                    lastTick = nil
                    persistDuration()
                }
            }
            .onChange(of: exItem.exerciseCompleted) { completed in
                if completed {
                    lastTick = nil
                    persistDuration()
                } else if isActive {
                    lastTick = Date()
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
                guard isActive && !exItem.exerciseCompleted else { return }
                if let last = lastTick {
                    let delta = Int(now.timeIntervalSince(last))
                    if delta > 0 {
                        elapsed += delta
                        lastTick = now
                        scheduleDebouncedPersist()
                    }
                } else {
                    lastTick = now
                }
            }

            // MARK: - Custom Time Editor Overlay
            if showingTimeEditor {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showingTimeEditor = false }

                timeEditor
                    .frame(maxWidth: 260)
                    .background(themeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    // MARK: - Time Editor
    private var timeEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Time")
                .bold()
                .foregroundColor(themeManager.currentTheme.textDefault)

            HStack(spacing: 6) {
                TextField("hh", text: $editHours)
                    .keyboardType(.numberPad)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.vertical, 8)
                    .multilineTextAlignment(.center)
                    .background(themeManager.currentTheme.formDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                    )
                    .frame(width: 50)

                Text(":").foregroundColor(themeManager.currentTheme.textDefault)

                TextField("mm", text: $editMinutes)
                    .keyboardType(.numberPad)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.vertical, 8)
                    .multilineTextAlignment(.center)
                    .background(themeManager.currentTheme.formDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                    )
                    .frame(width: 50)

                Text(":").foregroundColor(themeManager.currentTheme.textDefault)

                TextField("ss", text: $editSeconds)
                    .keyboardType(.numberPad)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.vertical, 8)
                    .multilineTextAlignment(.center)
                    .background(themeManager.currentTheme.formDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                    )
                    .frame(width: 50)
            }

            HStack {
                Spacer()
                Button("Save") {
                    let h = Int(editHours) ?? 0
                    let m = Int(editMinutes) ?? 0
                    let s = Int(editSeconds) ?? 0
                    let clampedH = max(0, h)
                    let clampedM = max(0, min(59, m))
                    let clampedS = max(0, min(59, s))
                    elapsed = clampedH * 3600 + clampedM * 60 + clampedS
                    showingTimeEditor = false
                    scheduleDebouncedPersist()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .onAppear {
            let hrs = elapsed / 3600
            let mins = (elapsed % 3600) / 60
            let secs = elapsed % 60
            editHours = String(format: "%02d", hrs)
            editMinutes = String(format: "%02d", mins)
            editSeconds = String(format: "%02d", secs)
        }
    }

    // MARK: - Helper Methods

    private func addSet() {
        // Enforce set limit based on premium status
        if exItem.sets.count >= maxSetsAllowed { return }

        guard let last = exItem.sets.last else { return }
        let repo = SessionSetRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        let now = Date()
        let lastReps: Int? = Int(last.repsText.trimmingCharacters(in: .whitespaces))
        let lastValue: Double? = Double(last.valueText.trimmingCharacters(in: .whitespaces))
        var currentUnit: String? = last.previousSet?.unit
        if currentUnit == nil {
            let persistedSets = (try? repo.bySessionExercise(last.sessionExerciseId)) ?? []
            currentUnit = persistedSets.last?.unit
        }
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
            newRec.id = newId
            let newItem = SessionSetItem(set: newRec, previousSet: last.previousSet)
            DispatchQueue.main.async {
                exItem.sets.append(newItem)
            }
        } catch {
            print("[ExerciseCardView] Failed to add set: \(error)")
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    private func persistDuration() {
        let repo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        if let exId = exItem.exercise.id {
            try? repo.updateDuration(id: exId, duration: elapsed)
        }
    }

    private func persistNote() {
        let repo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        if let exId = exItem.exercise.id {
            try? repo.updateNote(id: exId, note: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText)
        }
    }

    private func scheduleDebouncedPersist() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            persistDuration()
        }
    }

    private func scheduleNoteDebouncedSave() {
        noteSaveTask?.cancel()
        noteSaveTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            persistNote()
        }
    }
}

struct GrowingTextEditor: View {

    @EnvironmentObject var themeManager: ThemeManager

    @Binding var text: String
    let minLines: Int
    @State private var dynamicHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text + " ")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.clear)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(GeometryReader { geo in
                    themeManager.currentTheme.formDefault
                        .onAppear { dynamicHeight = clampHeight(geo.size.height) }
                        .onChange(of: text) { _ in dynamicHeight = clampHeight(geo.size.height) }
                })
            TextEditor(text: $text)
                .font(.body)
                .frame(height: max(dynamicHeight, lineHeight * CGFloat(minLines)))
                .scrollContentBackground(.hidden)
                .background(themeManager.currentTheme.formDefault)
        }
    }

    private var lineHeight: CGFloat { 20 }

    private func clampHeight(_ h: CGFloat) -> CGFloat {
        let minH = lineHeight * CGFloat(minLines)
        return max(h, minH)
    }
}

