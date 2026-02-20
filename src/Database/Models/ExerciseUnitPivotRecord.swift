//
//  ExerciseUnitPivotRecord.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseUnitPivotRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercise_unit_pivots"
    var id: Int64?
    var exerciseId: Int64
    var unitId: Int64
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case unitId = "unit_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Domain initializer
    init(from domain: ExerciseUnitPivotDomain) {
        self.id = domain.id
        self.exerciseId = Int64(domain.exerciseId)
        self.unitId = Int64(domain.unitId)
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    // Memberwise initializer for inserts
    init(id: Int64? = nil, exerciseId: Int64, unitId: Int64, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.exerciseId = exerciseId
        self.unitId = unitId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // ⚡ GRDB Columns enum
    enum Columns {
        static let id = Column("id")
        static let exerciseId = Column("exercise_id")
        static let unitId = Column("unit_id")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

// MARK: - Many-to-Many Helpers

extension ExerciseRecord {

    private enum ExerciseUnitError: Error {
        case missingID
    }

    /// Fetch all units attached to this exercise
    func units(_ db: Database) throws -> [UnitRecord] {
        let exerciseID = try id ?? { throw ExerciseUnitError.missingID }()
        return try UnitRecord
            .joining(
                required: UnitRecord
                    .belongsTo(
                        ExerciseUnitPivotRecord.self,
                        using: ForeignKey([ExerciseUnitPivotRecord.Columns.unitId], to: [UnitRecord.Columns.id])
                    )
                    .filter(ExerciseUnitPivotRecord.Columns.exerciseId == exerciseID)
            )
            .fetchAll(db)
    }

    /// Attach a unit to this exercise
    func attachUnit(_ unit: UnitRecord, db: Database) throws {
        let exerciseID = try id ?? { throw ExerciseUnitError.missingID }()
        guard let unitID = unit.id else { throw DatabaseError(message: "Unit must be persisted before attaching.") }

        let pivot = ExerciseUnitPivotRecord(
            id: nil,
            exerciseId: exerciseID,
            unitId: unitID,
            createdAt: Date(),
            updatedAt: Date()
        )
        try pivot.insert(db)
    }

    /// Detach a unit from this exercise
    func detachUnit(_ unit: UnitRecord, db: Database) throws {
        let exerciseID = try id ?? { throw ExerciseUnitError.missingID }()
        guard let unitID = unit.id else { return } // Silently ignore if not persisted

        try ExerciseUnitPivotRecord
            .filter(ExerciseUnitPivotRecord.Columns.exerciseId == exerciseID)
            .filter(ExerciseUnitPivotRecord.Columns.unitId == unitID)
            .deleteAll(db)
    }
}

extension UnitRecord {

    /// Attach an exercise to this unit
    func attachExercise(_ exercise: ExerciseRecord, db: Database) throws {
        let pivot = ExerciseUnitPivotRecord(
            id: nil,
            exerciseId: exercise.id!,
            unitId: self.id!,
            createdAt: Date(),
            updatedAt: Date()
        )
        try pivot.insert(db)
    }

    /// Detach an exercise from this unit
    func detachExercise(_ exercise: ExerciseRecord, db: Database) throws {
        try ExerciseUnitPivotRecord
            .filter(ExerciseUnitPivotRecord.Columns.exerciseId == exercise.id!)
            .filter(ExerciseUnitPivotRecord.Columns.unitId == self.id!)
            .deleteAll(db)
    }
}

