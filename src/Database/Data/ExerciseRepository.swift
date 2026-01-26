//
//  ExerciseRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

final class ExerciseRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAll(for userId: Int64) throws -> [ExerciseDomain] {
        try dbQueue.read { db in
            try ExerciseRecord
                .filter(Column("user_id") == userId)
                .fetchAll(db)
                .map { ExerciseDomain(from: $0) } // Row → Domain
        }
    }

    func createOrUpdate(_ exercise: ExerciseDomain) throws {
        try dbQueue.write { db in
            var record = ExerciseRecord(from: exercise) // Domain → Record
            try record.insert(db, onConflict: .replace)
        }
    }

    func delete(_ exercise: ExerciseDomain) throws {
        try dbQueue.write { db in
            if let id = exercise.id {
                _ = try ExerciseRecord.deleteOne(db, key: id)
            }
        }
    }
}

