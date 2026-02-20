//
//  ExerciseTagSeeder.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseTagSeeder {
    static func seed(db: Database) throws {
        // Only seed if table is empty (Laravel-style)
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM exercise_tags") ?? 0
        guard count == 0 else { return }

        let tags: [[String: Any]] = [
            // =======================
            // Group Tags
            // =======================
            ["name": "Core", "type": "Group"],
            ["name": "Abs", "type": "Group"],
            ["name": "Arms", "type": "Group"],
            ["name": "Biceps", "type": "Group"],
            ["name": "Triceps", "type": "Group"],
            ["name": "Back", "type": "Group"],
            ["name": "Chest", "type": "Group"],
            ["name": "Legs", "type": "Group"],
            ["name": "Quads", "type": "Group"],
            ["name": "Glutes", "type": "Group"],
            ["name": "Hamstrings", "type": "Group"],
            ["name": "Shoulders", "type": "Group"],
            ["name": "Full Body", "type": "Group"],
            ["name": "Cardio", "type": "Group"],
            ["name": "Other", "type": "Group"],
            ["name": "Hip Flexors", "type": "Group"],
            ["name": "Adductors", "type": "Group"],
            ["name": "Obliques", "type": "Group"],
            ["name": "Calves", "type": "Group"],
            ["name": "Groin", "type": "Group"],

            // =======================
            // Category Tags
            // =======================
            ["name": "Barbell", "type": "Category"],
            ["name": "Dumbbell", "type": "Category"],
            ["name": "Machine", "type": "Category"],
            ["name": "Bodyweight", "type": "Category"],
            ["name": "Reps Only", "type": "Category"],
            ["name": "Cardio", "type": "Category"],
            ["name": "Kettlebell", "type": "Category"],
            ["name": "Duration", "type": "Category"],
            ["name": "Other", "type": "Category"],
            
            // =======================
            // Category Tags
            // =======================
            ["name": "Push", "type": "Workout"],
            ["name": "Pull", "type": "Workout"],
            ["name": "Leg", "type": "Workout"],
            ["name": "Upper Body", "type": "Workout"],
            ["name": "Lower Body", "type": "Workout"],
            ["name": "Full Body", "type": "Workout"],
            ["name": "HIIT", "type": "Workout"],
            ["name": "Recovery", "type": "Workout"],
            ["name": "Cardio", "type": "Workout"],
            ["name": "Sport", "type": "Workout"],
            ["name": "Yoga", "type": "Workout"],
            ["name": "Core", "type": "Workout"],
        ]

        for tag in tags {
            try db.execute(
                sql: """
                INSERT INTO exercise_tags (name, type, created_at, updated_at)
                VALUES (:name, :type, :created_at, :updated_at)
                """,
                arguments: [
                    "name": tag["name"] as! String,
                    "type": tag["type"] as! String,
                    "created_at": Date(),
                    "updated_at": Date()
                ]
            )
        }

        print("🏷️ Seeded exercise_tags table with \(tags.count) records.")
    }
}
