import GRDB
import Foundation

struct WorkoutRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "workouts"

    var id: Int64?
    var userId: Int64
    var name: String
    var color: String
    var description: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        userId: Int64,
        name: String,
        color: String = "primary",
        description: String? = nil,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.description = description
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: WorkoutDomain) {
        self.id = domain.id
        self.userId = Int64(domain.userId)
        self.name = domain.name
        self.color = domain.color
        self.description = domain.description
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case color
        case description
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let name = Column("name")
        static let color = Column("color")
        static let description = Column("description")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

