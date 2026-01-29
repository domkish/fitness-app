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

        let count = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM exercise_unit_pivots"
        ) ?? 0
        guard count == 0 else { return }

        let exercises = try Row.fetchAll(db, sql: "SELECT id, name FROM exercises")
        let units = try Row.fetchAll(db, sql: "SELECT id, name FROM units")

        let exerciseMap = Dictionary(
            uniqueKeysWithValues: exercises.map {
                ($0["name"] as String, $0["id"] as Int)
            }
        )

        let unitMap = Dictionary(
            uniqueKeysWithValues: units.map {
                ($0["name"] as String, $0["id"] as Int)
            }
        )

        let distanceExercises: Set<String> = [
            "Walking",
            "Incline Walking",
            "Running",
            "Sprint",
            "Cycling",
            "Rowing"
        ]

        let distanceUnits = ["kilometer", "meter", "mile", "yard"]
        let weightUnits = ["kilograms", "pounds"]

        for (exerciseName, exerciseId) in exerciseMap {

            let unitNames = distanceExercises.contains(exerciseName)
                ? distanceUnits
                : weightUnits

            for unitName in unitNames {
                guard let unitId = unitMap[unitName] else {
                    fatalError("❌ Unit not found: \(unitName)")
                }

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

        print("🔗 Seeded exercise_unit_pivots table.")
    }
}
