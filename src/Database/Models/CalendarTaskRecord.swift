import GRDB
import Foundation

struct CalendarTaskRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "calendar_tasks"

    var id: Int64?
    var userId: Int64
    var taskId: Int64
    var date: String // ISO8601 YYYY-MM-DD
    var isComplete: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        userId: Int64,
        taskId: Int64,
        date: String,
        isComplete: Bool = false,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.date = date
        self.isComplete = isComplete
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskId = "task_id"
        case date
        case isComplete = "is_complete"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let taskId = Column("task_id")
        static let date = Column("date")
        static let isComplete = Column("is_complete")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

extension CalendarTaskRecord {
    init(domain: CalendarTask) {
        self.id = domain.id
        self.userId = domain.userId
        self.taskId = domain.taskId
        self.date = CalendarTask.dbString(from: domain.date) // convert Date -> "YYYY-MM-DD"
        self.isComplete = domain.isComplete
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
}
