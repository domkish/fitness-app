//
//  SessionExerciseRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//

import Foundation
import GRDB
struct SessionExerciseRepository {
    let dbQueue: DatabaseQueue

    func create(_ rec: inout SessionExerciseRecord) throws -> Int64 {
        return try dbQueue.write { db in
            try rec.insert(db)
            return rec.id ?? Int64(db.lastInsertedRowID)
        }
    }

    func bulkCreate(_ recs: inout [SessionExerciseRecord]) throws {
        try dbQueue.write { db in
            for i in recs.indices {
                try recs[i].insert(db)
            }
        }
    }

    func bySessionBlock(_ sessionBlockId: Int64) throws -> [SessionExerciseRecord] {
        return try dbQueue.read { db in
            try SessionExerciseRecord
                .filter(SessionExerciseRecord.Columns.sessionBlockId == sessionBlockId)
                .filter(SessionExerciseRecord.Columns.deletedAt == nil)
                .order(SessionExerciseRecord.Columns.order.asc)
                .fetchAll(db)
        }
    }
}

extension SessionExerciseRepository {
    func fetchTree(sessionBlockId: Int64, setRepo: SessionSetRepository) throws -> [(exercise: SessionExerciseRecord, sets: [SessionSetRecord])] {
        let exercises = try bySessionBlock(sessionBlockId)
        var result: [(SessionExerciseRecord, [SessionSetRecord])] = []
        for ex in exercises {
            let sets = try setRepo.bySessionExercise(ex.id ?? -1)
            result.append((ex, sets))
        }
        return result
    }
}
