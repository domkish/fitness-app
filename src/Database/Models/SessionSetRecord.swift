//
//  SessionSetRecord.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionSetRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var sessionExerciseId: Int64
    var setNumber: Int
    var completedReps: Int?
    var value: Double?
    var unit: String?
    var completed: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "session_sets"
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionExerciseId = "session_exercise_id"
        case setNumber = "set_number"
        case completedReps = "completed_reps"
        case value
        case unit
        case completed
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let sessionExerciseId = Column("session_exercise_id")
        static let setNumber = Column("set_number")
        static let completedReps = Column("completed_reps")
        static let value = Column("value")
        static let unit = Column("unit")
        static let completed = Column("completed")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    init(from domain: SessionSetDomain) {
        self.id = domain.id
        self.sessionExerciseId = domain.sessionExerciseId
        self.setNumber = domain.setNumber
        self.completedReps = domain.completedReps
        self.value = domain.value
        self.unit = domain.unit
        self.completed = domain.completed ? 1 : 0
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    func toDomain() -> SessionSetDomain {
        SessionSetDomain(
            id: id,
            sessionExerciseId: sessionExerciseId,
            setNumber: setNumber,
            completedReps: completedReps,
            value: value,
            unit: unit,
            completed: completed != 0,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
extension SessionSetRecord {
    init(
        id: Int64? = nil,
        sessionExerciseId: Int64,
        setNumber: Int,
        completedReps: Int? = nil,
        value: Double? = nil,
        unit: String? = nil,
        completed: Int = 0,
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

