//
//  ExerciseTagRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseTagRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var type: String
    var createdAt: Date
    var updatedAt: Date

    // Domain → Record initializer
    init(from domain: ExerciseTagDomain) {
        self.id = domain.id
        self.name = domain.name
        self.type = domain.type
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let type = Column("type")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

// MARK: - Many-to-Many Helpers

extension ExerciseTagRecord {

    /// Attach an exercise to this tag
    func attachExercise(_ exercise: ExerciseRecord, db: Database) throws {
        let pivot = ExerciseTagPivotRecord(
            id: nil,
            exerciseId: exercise.id!,
            exerciseTagId: self.id!,
            createdAt: Date(),
            updatedAt: Date()
        )
        try pivot.insert(db)
    }

    /// Detach an exercise from this tag
    func detachExercise(_ exercise: ExerciseRecord, db: Database) throws {
        try ExerciseTagPivotRecord
            .filter(ExerciseTagPivotRecord.Columns.exerciseId == exercise.id!)
            .filter(ExerciseTagPivotRecord.Columns.exerciseTagId == self.id!)
            .deleteAll(db)
    }
}
