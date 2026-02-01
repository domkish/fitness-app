//
//  SessionSetRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//

import Foundation
import GRDB
struct SessionSetRepository {
    let dbQueue: DatabaseQueue

    func create(_ rec: inout SessionSetRecord) throws -> Int64 {
        return try dbQueue.write { db in
            try rec.insert(db)
            return rec.id ?? Int64(db.lastInsertedRowID)
        }
    }

    func bulkCreate(_ recs: inout [SessionSetRecord]) throws {
        try dbQueue.write { db in
            for i in recs.indices {
                try recs[i].insert(db)
            }
        }
    }

    func bySessionExercise(_ sessionExerciseId: Int64) throws -> [SessionSetRecord] {
        return try dbQueue.read { db in
            try SessionSetRecord
                .filter(SessionSetRecord.Columns.sessionExerciseId == sessionExerciseId)
                .filter(SessionSetRecord.Columns.deletedAt == nil)
                .order(SessionSetRecord.Columns.setNumber.asc)
                .fetchAll(db)
        }
    }
}

extension SessionSetRepository {
    func updatePerformance(id: Int64, completedReps: Int?, value: Double?, unit: String?, completed: Bool) throws {
        try dbQueue.write { db in
            if var rec = try SessionSetRecord.fetchOne(db, key: id) {
                rec.completedReps = completedReps
                rec.value = value
                rec.unit = unit
                rec.completed = completed ? 1 : 0
                try rec.update(db)
            }
        }
    }
    func markCompleted(id: Int64, completed: Bool) throws {
        try dbQueue.write { db in
            if var rec = try SessionSetRecord.fetchOne(db, key: id) {
                rec.completed = completed ? 1 : 0
                try rec.update(db)
            }
        }
    }
}

