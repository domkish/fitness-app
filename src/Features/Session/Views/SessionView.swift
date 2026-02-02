//
//  SessionView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct SessionView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    let session: SessionRecord
    let sessionRepo: SessionRepository

    @State private var sessionTree: [SessionBlockItem] = []
    @State private var isLoading = true

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
                        Spacer()
                    }
                    .padding(.horizontal)

                    Group {
                        if isLoading {
                            VStack {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
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
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.vertical)
            }
        }
        .onAppear(perform: loadSessionTree)
    }

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
}

