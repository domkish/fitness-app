//
//  UnitMigration.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerUnitMigrations() {

        registerMigration("create_units") { db in
            try db.create(table: "units") { t in
                t.autoIncrementedPrimaryKey("id")

                // 1 = imperial, 0 = metric
                t.column("type", .boolean).notNull().defaults(to: true)
                    .indexed()
                t.column("name", .text)
                    .notNull()
                t.column("abbreviation", .text)
                    .notNull()
                t.timestamps()
            }
        }
    }
}
