import GRDB
import Foundation

final class WorkoutBlockRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func createOrUpdate(_ block: WorkoutBlockDomain) throws -> Int64 {
        try dbQueue.write { db in
            var record = WorkoutBlockRecord(from: block)
            if try record.exists(db) {
                record.updatedAt = Date()
                try record.update(db)
                return record.id ?? -1
            } else {
                try record.insert(db)
                return record.id ?? Int64(db.lastInsertedRowID)
            }
        }
    }
}

