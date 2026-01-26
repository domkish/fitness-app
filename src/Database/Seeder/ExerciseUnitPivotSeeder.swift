//
//  ExerciseUnitPivotSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseUnitPivotSeeder {

    static func seed(db: Database) throws {
        // Prevent double seeding
        let count = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM exercise_unit_pivots"
        ) ?? 0
        guard count == 0 else { return }

        // Fetch exercises
        let exercises = try Row.fetchAll(
            db,
            sql: "SELECT id, name FROM exercises"
        )

        // Fetch relevant units
        let distanceUnits = try Row.fetchAll(
            db,
            sql: "SELECT id, name FROM units WHERE name IN ('kilometer', 'meter', 'mile', 'yard')"
        )

        let weightUnits = try Row.fetchAll(
            db,
            sql: "SELECT id, name FROM units WHERE name IN ('kg', 'lbs')"
        )

        func unitId(named name: String, from units: [Row]) -> Int? {
            units.first { $0["name"] as? String == name }?["id"]
        }

        // Define distance-related keywords
        let distanceKeywords = ["run", "walk", "sprint", "cycle", "row", "jump"]

        for exercise in exercises {
            let exerciseId: Int = exercise["id"]
            let name = (exercise["name"] as String).lowercased()

            // Determine unit type
            let isDistance = distanceKeywords.contains { name.contains($0) }

            let selectedUnits: [Row] = isDistance ? distanceUnits : weightUnits

            // Insert pivot rows
            for unit in selectedUnits {
                let unitId: Int = unit["id"]
                try db.execute(
                    sql: """
                    INSERT INTO exercise_unit_pivots
                    (exercise_id, unit_id, created_at, updated_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    arguments: [
                        exerciseId,
                        unitId,
                        Date(),
                        Date()
                    ]
                )
            }
        }

        print("🔗 Seeded exercise_unit_pivots pivot table.")
    }
}
