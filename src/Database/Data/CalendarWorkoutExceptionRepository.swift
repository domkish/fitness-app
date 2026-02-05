import Foundation
import GRDB

struct CalendarWorkoutExceptionRepository {
    let dbQueue: DatabaseQueue
    
    func addSkip(calendarWorkoutId: Int64, on date: Date) throws -> Int64 {
        // Normalize date to midnight using CalendarWorkout helpers
        let normalizedDateString = CalendarWorkout.dbString(from: date)
        let now = Date()
        
        var insertedId: Int64 = 0
        
        try dbQueue.write { db in
            var record = CalendarWorkoutExceptionRecord(
                id: nil,
                calendarWorkoutId: calendarWorkoutId,
                date: normalizedDateString,
                deletedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try record.insert(db)
            insertedId = record.id ?? 0
        }
        
        return insertedId
    }
    
    func exists(calendarWorkoutId: Int64, on date: Date) throws -> Bool {
        let normalizedDateString = CalendarWorkout.dbString(from: date)
        
        return try dbQueue.read { db in
            try CalendarWorkoutExceptionRecord
                .filter(
                    CalendarWorkoutExceptionRecord.Columns.calendarWorkoutId == calendarWorkoutId &&
                    CalendarWorkoutExceptionRecord.Columns.date == normalizedDateString &&
                    CalendarWorkoutExceptionRecord.Columns.deletedAt == nil
                )
                .fetchOne(db) != nil
        }
    }
    
    func removeSkip(calendarWorkoutId: Int64, on date: Date) throws {
        let normalizedDateString = CalendarWorkout.dbString(from: date)
        let now = Date()
        
        try dbQueue.write { db in
            if var record = try CalendarWorkoutExceptionRecord
                .filter(
                    CalendarWorkoutExceptionRecord.Columns.calendarWorkoutId == calendarWorkoutId &&
                    CalendarWorkoutExceptionRecord.Columns.date == normalizedDateString &&
                    CalendarWorkoutExceptionRecord.Columns.deletedAt == nil
                )
                .fetchOne(db) {
                
                record.deletedAt = now
                record.updatedAt = now
                try record.update(db)
            }
        }
    }
}

