import Foundation
import GRDB

struct CalendarTaskRepository {
    let dbQueue: DatabaseQueue

    func tasks(on date: Date, userId: Int64) throws -> [CalendarTaskRecord] {
        let day = CalendarWorkout.dbString(from: date)
        return try dbQueue.read { db in
            try CalendarTaskRecord
                .filter(CalendarTaskRecord.Columns.userId == userId)
                .filter(CalendarTaskRecord.Columns.date == day)
                .filter(CalendarTaskRecord.Columns.deletedAt == nil)
                .order(CalendarTaskRecord.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    func toggleComplete(userId: Int64, taskId: Int64, date: Date) throws -> Int64 {
        try dbQueue.write { db in
            let day = CalendarWorkout.dbString(from: date)
            if var existing = try CalendarTaskRecord
                .filter(CalendarTaskRecord.Columns.userId == userId)
                .filter(CalendarTaskRecord.Columns.taskId == taskId)
                .filter(CalendarTaskRecord.Columns.date == day)
                .filter(CalendarTaskRecord.Columns.deletedAt == nil)
                .fetchOne(db) {
                existing.isComplete.toggle()
                existing.updatedAt = Date()
                try existing.update(db)
                return existing.id ?? Int64(db.lastInsertedRowID)
            } else {
                let rec = CalendarTaskRecord(
                    id: nil,
                    userId: userId,
                    taskId: taskId,
                    date: day,
                    isComplete: true,
                    deletedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try rec.insert(db)
                return rec.id ?? Int64(db.lastInsertedRowID)
            }
        }
    }
}
