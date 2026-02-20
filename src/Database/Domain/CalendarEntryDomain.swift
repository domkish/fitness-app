//
//  CalendarEntryDomain.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/30/26.
//

import Foundation
/// Domain model representing a row in `calendar_entries`.
///
/// Notes:
/// - `date` is stored as an ISO8601 string in the database; expose as `Date` in the domain model with helpers.
/// - `weight` and `bodyFat` are optional Doubles.
/// - `progressPhoto` stores a relative path inside the app sandbox (e.g., "progress_photos/2026-01-30_07-45-12.jpg").
/// - Soft delete is represented by `deletedAt`.
struct CalendarEntry: Identifiable, Sendable, Equatable {
    var id: Int64?
    var userId: Int64

    // Persisted as TEXT (ISO8601 date) in DB; represented as Date in domain
    var date: Date

    var weight: Double?
    var bodyFat: Double?
    var progressPhoto: String?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

// MARK: - Codable
extension CalendarEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case weight
        case bodyFat = "body_fat"
        case progressPhoto = "progress_photo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Date Formatting Helpers
extension CalendarEntry {
    /// A shared ISO8601DateFormatter for encoding/decoding the `date` field to/from database TEXT.
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

