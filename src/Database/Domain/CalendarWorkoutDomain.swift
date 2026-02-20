//
//  CalendarWorkoutDomain.swift
//  SimplyFitness
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
    /// A shared DateFormatter for encoding/decoding date-only fields to/from database TEXT.
    /// We intentionally format using the user's current calendar and time zone so the stored
    /// YYYY-MM-DD corresponds to the day the user selected in the UI (no UTC day-shift).
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    /// Convert a Date to the DB string (YYYY-MM-DD) using the user's calendar day.
    static func dbString(from date: Date) -> String {
        // Ensure we take the start of the day in the user's current calendar/time zone
        let dayStart = Calendar.current.startOfDay(for: date)
        return dayFormatter.string(from: dayStart)
    }

    /// Parse DB date string (YYYY-MM-DD) back to a Date at the start of that day in the user's time zone.
    static func date(from dbString: String) -> Date? {
        guard let d = dayFormatter.date(from: dbString) else { return nil }
        return Calendar.current.startOfDay(for: d)
    }
}

