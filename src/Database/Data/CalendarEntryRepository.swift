//
//  CalendarEntryRepository.swift
//  SimplyFitness
//
//  Created by Assistant on 1/30/26.
//

import Foundation
import GRDB

struct CalendarEntryRepository {
    let dbQueue: DatabaseQueue

    // MARK: - Fetch
    func entry(for userId: Int64, on date: Date) throws -> CalendarEntryRecord? {
        let dateString = CalendarEntry.dbString(from: date)
        return try dbQueue.read { db in
            try CalendarEntryRecord
                .filter(CalendarEntryRecord.Columns.userId == userId && CalendarEntryRecord.Columns.date == dateString)
                .filter(CalendarEntryRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    func mostRecentPriorEntry(before date: Date, userId: Int64) throws -> CalendarEntryRecord? {
        let dateString = CalendarEntry.dbString(from: date)
        return try dbQueue.read { db in
            try CalendarEntryRecord
                .filter(CalendarEntryRecord.Columns.userId == userId && CalendarEntryRecord.Columns.date < dateString)
                .filter(CalendarEntryRecord.Columns.deletedAt == nil)
                .order(CalendarEntryRecord.Columns.date.desc)
                .fetchOne(db)
        }
    }

    func entries(in range: ClosedRange<Date>, userId: Int64) throws -> [CalendarEntryRecord] {
        let start = CalendarEntry.dbString(from: range.lowerBound)
        let end = CalendarEntry.dbString(from: range.upperBound)
        return try dbQueue.read { db in
            try CalendarEntryRecord
                .filter(CalendarEntryRecord.Columns.userId == userId)
                .filter(CalendarEntryRecord.Columns.date >= start && CalendarEntryRecord.Columns.date <= end)
                .filter(CalendarEntryRecord.Columns.deletedAt == nil)
                .order(CalendarEntryRecord.Columns.date.asc)
                .fetchAll(db)
        }
    }

    // MARK: - Save / Upsert
    func upsert(_ domain: CalendarEntry) throws {
        let record = CalendarEntryRecord(from: domain)
        try dbQueue.write { db in
            try record.save(db)
        }
    }
}

