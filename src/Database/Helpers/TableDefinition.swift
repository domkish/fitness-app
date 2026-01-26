//
//  TableDefinition.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension TableDefinition {

    nonisolated func timestamps() {
        column("created_at", .datetime).notNull()
        column("updated_at", .datetime).notNull()
    }

    nonisolated func softDeletes() {
        column("deleted_at", .datetime)
    }

    nonisolated func foreignId(
        _ name: String,
        references table: String,
        onDelete: Database.ForeignKeyAction = .cascade
    ) {
        column(name, .integer)
            .notNull()
            .references(table, onDelete: onDelete)
    }
}
