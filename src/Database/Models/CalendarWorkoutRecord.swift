//
//  CalendarWorkoutRecord.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import GRDB
import Foundation

struct CalendarWorkoutRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "calendar_workouts"

    var id: Int64?
    var userId: Int64
    var workoutId: Int64
    var startsOn: String // ISO8601 YYYY-MM-DD
    var endsOn: String?
    var frequency: Int?
    var mon: Bool
    var tues: Bool
    var wed: Bool
    var thurs: Bool
    var fri: Bool
    var sat: Bool
    var sun: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        userId: Int64,
        workoutId: Int64,
        startsOn: String,
        endsOn: String? = nil,
        frequency: Int? = nil,
        mon: Bool = false,
        tues: Bool = false,
        wed: Bool = false,
        thurs: Bool = false,
        fri: Bool = false,
        sat: Bool = false,
        sun: Bool = false,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.frequency = frequency
        self.mon = mon
        self.tues = tues
        self.wed = wed
        self.thurs = thurs
        self.fri = fri
        self.sat = sat
        self.sun = sun
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: CalendarWorkout) {
        self.id = domain.id
        self.userId = domain.userId
        self.workoutId = domain.workoutId
        self.startsOn = CalendarWorkout.dbString(from: domain.startsOn)
        self.endsOn = domain.endsOn.map { CalendarWorkout.dbString(from: $0) }
        self.frequency = domain.frequency
        self.mon = domain.mon
        self.tues = domain.tues
        self.wed = domain.wed
        self.thurs = domain.thurs
        self.fri = domain.fri
        self.sat = domain.sat
        self.sun = domain.sun
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case frequency
        case mon, tues, wed, thurs, fri, sat, sun
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let workoutId = Column("workout_id")
        static let startsOn = Column("starts_on")
        static let endsOn = Column("ends_on")
        static let frequency = Column("frequency")
        static let mon = Column("mon")
        static let tues = Column("tues")
        static let wed = Column("wed")
        static let thurs = Column("thurs")
        static let fri = Column("fri")
        static let sat = Column("sat")
        static let sun = Column("sun")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}
