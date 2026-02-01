import Foundation
import GRDB

struct SessionBlockRepository {
    let dbQueue: DatabaseQueue

    func create(_ rec: inout SessionBlockRecord) throws -> Int64 {
        return try dbQueue.write { db in
            try rec.insert(db)
            return rec.id ?? Int64(db.lastInsertedRowID)
        }
    }

    func bulkCreate(_ recs: inout [SessionBlockRecord]) throws {
        try dbQueue.write { db in
            for i in recs.indices {
                try recs[i].insert(db)
            }
        }
    }

    func bySession(_ sessionId: Int64) throws -> [SessionBlockRecord] {
        return try dbQueue.read { db in
            try SessionBlockRecord
                .filter(SessionBlockRecord.Columns.sessionId == sessionId)
                .filter(SessionBlockRecord.Columns.deletedAt == nil)
                .order(SessionBlockRecord.Columns.id.asc)
                .fetchAll(db)
        }
    }
}

extension SessionBlockRepository {
    func fetchTree(sessionId: Int64, exRepo: SessionExerciseRepository, setRepo: SessionSetRepository) throws -> [(block: SessionBlockRecord, exercises: [(exercise: SessionExerciseRecord, sets: [SessionSetRecord])])] {
        let blocks = try bySession(sessionId)
        var result: [(block: SessionBlockRecord, exercises: [(exercise: SessionExerciseRecord, sets: [SessionSetRecord])])] = []
        for block in blocks {
            let exercises = try exRepo.bySessionBlock(block.id ?? -1)
            var exWithSets: [(exercise: SessionExerciseRecord, sets: [SessionSetRecord])] = []
            for ex in exercises {
                let sets = try setRepo.bySessionExercise(ex.id ?? -1)
                exWithSets.append((exercise: ex, sets: sets))
            }
            result.append((block: block, exercises: exWithSets))
        }
        return result
    }
}

