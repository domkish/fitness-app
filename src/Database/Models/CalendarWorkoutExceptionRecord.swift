//
//  CalendarWorkoutExceptionRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/4/26.
//
import GRDB
import Foundation

struct CalendarWorkoutExceptionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "calendar_workout_exceptions"

    var id: Int64?
    var calendarWorkoutId: Int64
    var date: String
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        calendarWorkoutId: Int64,
        date: String,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.calendarWorkoutId = calendarWorkoutId
        self.date = date
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: CalendarWorkoutException) {
        self.id = domain.id
        self.calendarWorkoutId = domain.calendarWorkoutId
        self.date = CalendarWorkout.dbString(from: domain.date)
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case calendarWorkoutId = "calendar_workout_id"
        case date
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let calendarWorkoutId = Column("calendar_workout_id")
        static let date = Column("date")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

