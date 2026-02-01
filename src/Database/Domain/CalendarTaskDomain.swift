import Foundation

/// Domain model representing a row in `calendar_tasks`.
/// Tracks per-day completion for a task.
public struct CalendarTask: Identifiable, Sendable, Equatable, Codable {
    public var id: Int64?
    public var userId: Int64
    public var taskId: Int64
    public var date: Date
    public var isComplete: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: Int64? = nil,
        userId: Int64,
        taskId: Int64,
        date: Date,
        isComplete: Bool,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.date = date
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskId = "task_id"
        case date
        case isComplete = "is_complete"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Date formatting helpers (YYYY-MM-DD)
public extension CalendarTask {
    /// Shared ISO8601 date-only formatter (UTC) for db strings
    static let iso8601DateOnlyFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Convert a Date to DB string (YYYY-MM-DD)
    static func dbString(from date: Date) -> String {
        iso8601DateOnlyFormatter.string(from: date)
    }

    /// Parse DB date string (YYYY-MM-DD) to Date (at midnight UTC)
    static func date(from dbString: String) -> Date? {
        iso8601DateOnlyFormatter.date(from: dbString)
    }
}
