//
//  User.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import Foundation
import GRDB

struct UserRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "users"

    var id: Int
    var name: String
    var email: String
    var isPremium: Bool
    var isImperial: Bool
    var weight: Bool
    var fat: Bool
    var photo: Bool
    var log: Int?
    var theme: String
    var emailVerifiedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Map Swift properties to actual column names
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let email = Column("email")
        static let isPremium = Column("is_premium")
        static let isImperial = Column("is_imperial")
        static let weight = Column("weight")
        static let fat = Column("fat")
        static let photo = Column("photo")
        static let log = Column("log")
        static let theme = Column("theme")
        static let emailVerifiedAt = Column("email_verified_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    // GRDB persistence
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.email] = email
        container[Columns.isPremium] = isPremium
        container[Columns.isImperial] = isImperial
        container[Columns.weight] = weight
        container[Columns.fat] = fat
        container[Columns.photo] = photo
        container[Columns.log] = log
        container[Columns.theme] = theme
        container[Columns.emailVerifiedAt] = emailVerifiedAt
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        email = row[Columns.email]
        isPremium = row[Columns.isPremium]
        isImperial = row[Columns.isImperial] ?? true
        weight = row[Columns.weight] ?? true
        fat = row[Columns.fat] ?? true
        photo = row[Columns.photo] ?? true
        log = row[Columns.log]
        theme = row[Columns.theme] ?? "classic"
        emailVerifiedAt = row[Columns.emailVerifiedAt]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }

    init(from user: User) {
        id = user.id
        name = user.name
        email = user.email
        isPremium = user.isPremium
        isImperial = user.isImperial
        weight = user.weight
        fat = user.fat
        photo = user.photo
        log = user.log
        theme = user.theme
        emailVerifiedAt = user.emailVerifiedAt
        createdAt = user.createdAt
        updatedAt = user.updatedAt
    }
}

