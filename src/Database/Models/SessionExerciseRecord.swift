//
//  SessionExerciseRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionExerciseRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var sessionBlockId: Int64
    var exerciseId: Int64
    var exerciseName: String
    var note: String?
    var order: Int?
    var duration: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "session_exercises"

    enum Columns: String, ColumnExpression {
        case id
        case sessionBlockId = "session_block_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case note
        case order
        case duration
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: Int64? = nil,
        sessionBlockId: Int64,
        exerciseId: Int64,
        exerciseName: String,
        note: String? = nil,
        order: Int? = nil,
        duration: Int = 0,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionBlockId = sessionBlockId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.note = note
        self.order = order
        self.duration = duration
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: SessionExerciseDomain) {
        self.id = domain.id
        self.sessionBlockId = domain.sessionBlockId
        self.exerciseId = domain.exerciseId
        self.exerciseName = domain.exerciseName
        self.note = domain.note
        self.order = domain.order
        self.duration = domain.duration
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    func toDomain() -> SessionExerciseDomain {
        SessionExerciseDomain(
            id: id,
            sessionBlockId: sessionBlockId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            note: note,
            order: order,
            duration: duration,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

