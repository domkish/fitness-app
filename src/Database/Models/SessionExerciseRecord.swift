//
//  SessionExerciseRecord.swift
//  SimplyFitness
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
    var unit: String?
    var order: Int?
    var duration: Int
    var completed: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "session_exercises"
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionBlockId = "session_block_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case note
        case unit
        case order
        case duration
        case completed
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let sessionBlockId = Column("session_block_id")
        static let exerciseId = Column("exercise_id")
        static let exerciseName = Column("exercise_name")
        static let note = Column("note")
        static let unit = Column("unit")
        static let order = Column("order")
        static let duration = Column("duration")
        static let completed = Column("completed")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
    

    init(
        id: Int64? = nil,
        sessionBlockId: Int64,
        exerciseId: Int64,
        exerciseName: String,
        note: String? = nil,
        unit: String? = nil,
        order: Int? = nil,
        duration: Int = 0,
        completed: Int = 0,
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

    init(from domain: SessionExerciseDomain) {
        self.id = domain.id
        self.sessionBlockId = domain.sessionBlockId
        self.exerciseId = domain.exerciseId
        self.exerciseName = domain.exerciseName
        self.note = domain.note
        self.unit = domain.unit
        self.order = domain.order
        self.duration = domain.duration
        self.completed = domain.completed ? 1 : 0
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
            unit: unit,
            order: order,
            duration: duration,
            completed: completed != 0,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

