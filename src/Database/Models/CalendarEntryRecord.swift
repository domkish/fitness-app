//
//  CalendarEntryRecord.swift
//  SimplyFitness
//
//  Created by Assistant on 1/30/26.
//

import GRDB
import Foundation

struct CalendarEntryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "calendar_entries"

    var id: Int64?
    var userId: Int64
    var date: String // stored as ISO8601 YYYY-MM-DD in DB
    var weight: Double?
    var bodyFat: Double?
    var progressPhoto: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        userId: Int64,
        date: String,
        weight: Double? = nil,
        bodyFat: Double? = nil,
        progressPhoto: String? = nil,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.weight = weight
        self.bodyFat = bodyFat
        self.progressPhoto = progressPhoto
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: CalendarEntry) {
        self.id = domain.id
        self.userId = domain.userId
        self.date = CalendarEntry.dbString(from: domain.date)
        self.weight = domain.weight
        self.bodyFat = domain.bodyFat
        self.progressPhoto = domain.progressPhoto
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case weight
        case bodyFat = "body_fat"
        case progressPhoto = "progress_photo"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let date = Column("date")
        static let weight = Column("weight")
        static let bodyFat = Column("body_fat")
        static let progressPhoto = Column("progress_photo")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}
