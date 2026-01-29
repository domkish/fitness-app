//
//  TaskRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/29/26.
//

import Foundation
import GRDB
struct TaskRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tasks"
    
    var id: Int64?
    var userId: Int64?
    var name: String
    var sunday: Bool
    var monday: Bool
    var tuesday: Bool
    var wednesday: Bool
    var thursday: Bool
    var friday: Bool
    var saturday: Bool
    var startedAt: Date?
    var endsAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: Int64?,
        userId: Int64?,
        name: String,
        sunday: Bool,
        monday: Bool,
        tuesday: Bool,
        wednesday: Bool,
        thursday: Bool,
        friday: Bool,
        saturday: Bool,
        startedAt: Date?,
        endsAt: Date?,
        deletedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.sunday = sunday
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case sunday
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case startedAt = "started_at"
        case endsAt = "ends_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from domain: TaskDomain) {
        self.id = domain.id
        self.userId = domain.userId.flatMap { Int64($0) }
        self.name = domain.name
        self.sunday = domain.sunday
        self.monday = domain.monday
        self.tuesday = domain.tuesday
        self.wednesday = domain.wednesday
        self.thursday = domain.thursday
        self.friday = domain.friday
        self.saturday = domain.saturday
        self.startedAt = domain.startedAt
        self.endsAt = domain.endsAt
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let name = Column("name")
        static let sunday = Column("sunday")
        static let monday = Column("monday")
        static let tuesday = Column("tuesday")
        static let wednesday = Column("wednesday")
        static let thursday = Column("thursday")
        static let friday = Column("friday")
        static let saturday = Column("saturday")
        static let startedAt = Column("started_at")
        static let endsAt = Column("ends_at")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

