//
//  SessionSetDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation

struct SessionSetDomain {
    var id: Int64?
    var sessionExerciseId: Int64
    var setNumber: Int
    var completedReps: Int?
    var value: Double?
    var unit: String?
    var completed: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        sessionExerciseId: Int64,
        setNumber: Int,
        completedReps: Int? = nil,
        value: Double? = nil,
        unit: String? = nil,
        completed: Bool = false,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionExerciseId = sessionExerciseId
        self.setNumber = setNumber
        self.completedReps = completedReps
        self.value = value
        self.unit = unit
        self.completed = completed
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
