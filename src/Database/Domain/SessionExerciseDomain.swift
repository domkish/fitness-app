//
//  SessionExerciseDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation

struct SessionExerciseDomain {
    var id: Int64?
    var sessionBlockId: Int64
    var exerciseId: Int64
    var exerciseName: String
    var note: String?
    var unit: String?
    var order: Int?
    var duration: Int
    var completed: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        sessionBlockId: Int64,
        exerciseId: Int64,
        exerciseName: String,
        note: String? = nil,
        unit: String? = nil,
        order: Int? = nil,
        duration: Int = 0,
        completed: Bool = false,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionBlockId = sessionBlockId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.note = note
        self.unit = unit
        self.order = order
        self.duration = duration
        self.completed = completed
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

