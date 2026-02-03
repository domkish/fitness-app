//
//  SessionModelView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import SwiftUI
import Combine

class SessionSetItem: ObservableObject, Identifiable {
    let id = UUID()
    let setId: Int64?
    let sessionExerciseId: Int64
    let setNumber: Int
    let unit: String?
    var previousSet: SessionSetRecord?

    @Published var repsText: String
    @Published var valueText: String
    @Published var completed: Bool

    init(set: SessionSetRecord, previousSet: SessionSetRecord? = nil) {
        self.setId = set.id
        self.sessionExerciseId = set.sessionExerciseId
        self.setNumber = set.setNumber
        self.unit = set.unit
        self.repsText = (set.completedReps != nil) ? String(set.completedReps!) : ""
        if let v = set.value {
            self.valueText = String(v)
        } else {
            self.valueText = ""
        }
        self.completed = set.completed != 0
        self.previousSet = previousSet
    }
}

class SessionExerciseItem: ObservableObject, Identifiable {
    let id = UUID()
    let exercise: SessionExerciseRecord
    @Published var exerciseCompleted: Bool
    @Published var sets: [SessionSetItem]

    init(exercise: SessionExerciseRecord, sets: [SessionSetItem]) {
        self.exerciseCompleted = (exercise.completed != 0)
        self.sets = sets
        self.exercise = exercise
    }
}

class SessionBlockItem: ObservableObject, Identifiable {
    let id = UUID()
    let block: SessionBlockRecord
    @Published var exercises: [SessionExerciseItem]

    init(block: SessionBlockRecord, exercises: [SessionExerciseItem]) {
        self.block = block
        self.exercises = exercises
    }
}

