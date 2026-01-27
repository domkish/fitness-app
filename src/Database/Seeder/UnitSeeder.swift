//
//  UnitSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct UnitSeeder {

    static func seed(db: Database) throws {
        // Only seed if table is empty (Laravel-style)
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM units") ?? 0
        guard count == 0 else { return }

        let units: [[String: Any]] = [
            // Length
            ["type": 0, "name": "kilometer", "abbreviation": "km"],
            ["type": 0, "name": "meter", "abbreviation": "m"],
            ["type": 1, "name": "mile", "abbreviation": "mi"],
            ["type": 1, "name": "yard", "abbreviation": "yd"],

            // Mass / Weight
            ["type": 0, "name": "kilograms", "abbreviation": "kg"],
            ["type": 1, "name": "pounds", "abbreviation": "lbs"],

            // Volume
            ["type": 0, "name": "liter", "abbreviation": "L"],
            ["type": 1, "name": "gallon", "abbreviation": "gal"],
        ]

        // Insert units
        for unit in units {
            try db.execute(
                sql: """
                INSERT INTO units (type, name, abbreviation, created_at, updated_at)
                VALUES (:type, :name, :abbreviation, :created_at, :updated_at)
                """,
                arguments: [
                    "type": unit["type"] as! Int,
                    "name": unit["name"] as! String,
                    "abbreviation": unit["abbreviation"] as! String,
                    "created_at": Date(),
                    "updated_at": Date()
                ]
            )
        }

        print("📝 Seeded units table with \(units.count) records.")
    }
}
