//
//  SessionExerciseRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionBlockRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var sessionId: Int64
    var workoutBlockId: Int64
    var duration: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "session_exercises"

    enum Columns: String, ColumnExpression {
        case id
        case sessionId = "session_id"
        case workoutBlockId = "workout_block_id"
        case duration
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from domain: SessionBlockDomain) {
        self.id = domain.id
        self.sessionId = domain.sessionId
        self.workoutBlockId = domain.workoutBlockId
        self.duration = domain.duration
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    func toDomain() -> SessionBlockDomain {
        SessionBlockDomain(
            id: id,
            sessionId: sessionId,
            workoutBlockId: workoutBlockId,
            duration: duration,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
