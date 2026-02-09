//
//  UserMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//

import GRDB

extension DatabaseMigrator {

    mutating func registerUserMigrations() {

        registerMigration("create_users") { db in
            try db.create(table: "users") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("email", .text).notNull().unique()
                t.column("is_premium", .boolean).notNull()
                t.column("is_imperial", .boolean).notNull().defaults(to: true)
                t.column("weight", .boolean).notNull().defaults(to: true)
                t.column("fat", .boolean).notNull().defaults(to: true)
                t.column("photo", .boolean).notNull().defaults(to: true)
                t.column("log", .integer)
                t.column("theme", .text).notNull().defaults(to: "classic")
                t.column("email_verified_at", .datetime)
                t.column("token", .text)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}

