//
//  UnitRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct UnitRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "units"
    
    var id: Int64?
    var type: Int?          // 1 = imperial, 0 = metric (nullable)
    var name: String
    var abbreviation: String
    var createdAt: Date
    var updatedAt: Date

    // Domain → Record initializer
    init(from domain: UnitDomain) {
        self.id = domain.id
        self.type = domain.type
        self.name = domain.name
        self.abbreviation = domain.abbreviation
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let type = Column("type")
        static let name = Column("name")
        static let abbreviation = Column("abbreviation")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

