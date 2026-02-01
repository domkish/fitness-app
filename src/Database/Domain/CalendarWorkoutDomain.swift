//
//  CalendarWorkoutDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/30/26.
//

import Foundation
/// Domain model representing a row in `calendar_workouts`.
///
/// Notes:
/// - `startsOn`/`endsOn` are stored as ISO8601 date-only strings in the database; expose as `Date` in the domain model with helpers.
/// - `frequency` is an optional small integer (nil = one-time, 1 = weekly, 2 = every 2 weeks, etc.).
/// - Day-of-week flags are booleans.
struct CalendarWorkout: Identifiable, Sendable, Equatable {
    var id: Int64?
    var userId: Int64
    var workoutId: Int64

    var startsOn: Date
    var endsOn: Date?

    var frequency: Int?

    var mon: Bool
    var tues: Bool
    var wed: Bool
    var thurs: Bool
    var fri: Bool
    var sat: Bool
    var sun: Bool

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

// MARK: - Codable
extension CalendarWorkout: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case frequency
        case mon, tues, wed, thurs, fri, sat, sun
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Date Formatting Helpers
extension CalendarWorkout {
    /// A shared ISO8601DateFormatter for encoding/decoding date-only fields to/from database TEXT.
    static let iso8601DateOnlyFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Convert a Date to the DB string (YYYY-MM-DD)
    static func dbString(from date: Date) -> String {
        iso8601DateOnlyFormatter.string(from: date)
    }

    /// Parse DB date string (YYYY-MM-DD) to Date (at midnight UTC)
    static func date(from dbString: String) -> Date? {
        iso8601DateOnlyFormatter.date(from: dbString)
    }
}

