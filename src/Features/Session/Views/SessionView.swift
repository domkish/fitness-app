//
//  SessionView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import GRDB

struct SessionView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let session: SessionRecord
    let sessionRepo: SessionRepository
    let onCompleted: ((SessionRecord) -> Void)?
    var hideCompleteButton: Bool = false

    @State private var sessionTree: [SessionBlockItem] = []
    @State private var isLoading = true
    @State private var showingCompleteAlert = false
    @State private var showSummary = false

    var body: some View {
        ZStack {
            themeManager.currentTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text(session.workoutName)
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text(session.description ?? "")
                            .foregroundColor(themeManager.currentTheme.muted)
                    }
                    .padding(.horizontal)

                    Group {
                        if isLoading {
                            VStack {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                            .padding(.horizontal)
                        } else {
                            ForEach(sessionTree) { block in
                                BlockCardView(blockItem: block)
                                    .environmentObject(themeManager)
                                    .padding(.horizontal)
                            }

                            // Bottom Complete Workout button
                            if !hideCompleteButton {
                                HStack {
                                    Button(action: { showingCompleteAlert = true }) {
                                        HStack {
                                            Spacer()
                                            Text("Complete Workout")
                                                .bold()
                                            Spacer()
                                        }
                                        .padding()
                                        .background(themeManager.currentTheme.primary)
                                        .foregroundColor(themeManager.currentTheme.background)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.vertical)
            }

            // MARK: - Complete Workout Confirmation Popup
            if showingCompleteAlert {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingCompleteAlert = false
                    }

                VStack(spacing: 16) {
                    Text("Complete Workout?")
                        .font(.title3)
                        .bold()
                        .foregroundColor(themeManager.currentTheme.textDefault)

                    Text("Are you sure you want to complete this workout? You can review the summary afterward.")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Button {
                            showingCompleteAlert = false
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.currentTheme.surface)
                                .cornerRadius(8)
                        }

                        Button {
                            showingCompleteAlert = false
                            Task { await completeWorkout() }
                        } label: {
                            Text("Complete")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(themeManager.currentTheme.primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(24)
                .background(themeManager.currentTheme.background)
                .cornerRadius(16)
                .padding(.horizontal, 40)
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showingCompleteAlert)
        .onAppear(perform: loadSessionTree)
        .toolbar {
            if hideCompleteButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadSessionTree() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tree = try sessionRepo.fetchSessionTree(
                    calendarWorkoutId: session.calendarWorkoutId,
                    startedAt: session.startedAt ?? Date()
                )

                let mapped = tree.map { blockTuple in
                    SessionBlockItem(
                        block: blockTuple.block,
                        exercises: blockTuple.exercises.map { exTuple in
                            SessionExerciseItem(
                                exercise: exTuple.exercise,
                                sets: exTuple.sets.map { set in
                                    let prevSet = try? sessionRepo.fetchPreviousSet(
                                        for: set.sessionExerciseId,
                                        before: session.startedAt ?? Date()
                                    )
                                    return SessionSetItem(set: set, previousSet: prevSet)
                                }
                            )
                        }
                    )
                }

                DispatchQueue.main.async {
                    self.sessionTree = mapped
                    self.isLoading = false
                }
            } catch {
                print("Failed to load session tree: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Completion

    private func completeWorkout() async {
        do {
            let exRepo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let blockRepo = SessionBlockRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

            let blocks = try blockRepo.bySession(session.id ?? -1)
            var total: Int = 0

            for b in blocks {
                let exercises = try exRepo.bySessionBlock(b.id ?? -1)
                let sumForBlock = exercises.reduce(0) { $0 + $1.duration }
                total += sumForBlock
                try updateBlockDuration(blockId: b.id ?? -1, to: sumForBlock)
            }
            
            try updateSessionCompletion(totalDuration: total)

            await MainActor.run { onCompleted?(session) }
        } catch {
            print("[SessionView] completeWorkout error: \(error)")
        }
    }
    
    private func updateSessionCompletion(totalDuration: Int) throws {
        try sessionRepo.dbQueue.write { db in
            if var rec = try SessionRecord.fetchOne(db, key: session.id) {
                rec.totalDuration = totalDuration
                rec.completedAt = Date()
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }

    private func updateBlockDuration(blockId: Int64, to duration: Int) throws {
        try sessionRepo.dbQueue.write { db in
            if var rec = try SessionBlockRecord.fetchOne(db, key: blockId) {
                rec.duration = duration
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }
}

