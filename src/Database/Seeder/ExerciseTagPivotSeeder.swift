//
//  ExerciseTagPivotSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseTagPivotSeeder {

    static func seed(db: Database) throws {
        // Prevent double seeding: check the PIVOT table
        let pivotCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM exercise_tag_pivots"
        ) ?? 0
        guard pivotCount == 0 else { return }

        // Fetch exercises (from exercises table)
        let exercises = try Row.fetchAll(
            db,
            sql: "SELECT id, name FROM exercises"
        )

        // Fetch tags with their types (from exercise_tags table)
        let tags = try Row.fetchAll(
            db,
            sql: "SELECT id, name, type FROM exercise_tags"
        )

        let groupTags = tags.filter { ($0["type"] as String?) == "Group" }
        let categoryTags = tags.filter { ($0["type"] as String?) == "Category" }
        let workoutTags = tags.filter { ($0["type"] as String?) == "Workout" }

        func tagId(named name: String, from tags: [Row]) -> Int? {
            tags.first { ($0["name"] as String?) == name }?["id"]
        }

        for exercise in exercises {
            let exerciseId: Int = exercise["id"]
            let name = (exercise["name"] as String).lowercased()

            var selectedTagIds: Set<Int> = []

            // GROUP TAGS (1–3)
            let groupRules: [(String, String)] = [
                ("plank", "Core"),
                ("crunch", "Abs"),
                ("curl", "Biceps"),
                ("tricep", "Triceps"),
                ("row", "Back"),
                ("pull", "Back"),
                ("press", "Chest"),
                ("squat", "Legs"),
                ("deadlift", "Legs"),
                ("lunge", "Legs"),
                ("calf", "Legs"),
                ("shoulder", "Shoulders"),
                ("raise", "Shoulders"),
                ("burpee", "Full Body"),
                ("clean", "Full Body"),
                ("snatch", "Full Body"),
                ("run", "Cardio"),
                ("walk", "Cardio"),
                ("cycle", "Cardio"),
                ("rower", "Cardio"),
            ]

            for (keyword, tagName) in groupRules {
                if name.contains(keyword),
                   let id = tagId(named: tagName, from: groupTags) {
                    selectedTagIds.insert(id)
                }
            }

            if selectedTagIds.isEmpty,
               let otherId = tagId(named: "Other", from: groupTags) {
                selectedTagIds.insert(otherId)
            }

            selectedTagIds = Set(selectedTagIds.prefix(3))

            // CATEGORY TAGS (1–2)
            let categoryRules: [(String, String)] = [
                ("barbell", "Barbell"),
                ("dumbbell", "Dumbbell"),
                ("cable", "Machine"),
                ("machine", "Machine"),
                ("bodyweight", "Bodyweight"),
                ("push-up", "Bodyweight"),
                ("pull-up", "Bodyweight"),
                ("plank", "Bodyweight"),
                ("run", "Cardio"),
                ("walk", "Cardio"),
                ("cycle", "Cardio"),
            ]

            var categoryIds: [Int] = []

            for (keyword, tagName) in categoryRules {
                if name.contains(keyword),
                   let id = tagId(named: tagName, from: categoryTags) {
                    categoryIds.append(id)
                }
            }

            if categoryIds.isEmpty,
               let repsOnly = tagId(named: "Reps Only", from: categoryTags) {
                categoryIds.append(repsOnly)
            }

            categoryIds.prefix(2).forEach { selectedTagIds.insert($0) }

            // WORKOUT TAGS (1–2)
            let workoutRules: [(String, String)] = [
                ("press", "Push"),
                ("push-up", "Push"),
                ("dip", "Push"),
                ("row", "Pull"),
                ("pull-up", "Pull"),
                ("curl", "Pull"),
                ("squat", "Leg"),
                ("lunge", "Leg"),
                ("deadlift", "Leg"),
                ("burpee", "Hiit"),
                ("jump", "Hiit"),
                ("sprint", "Hiit"),
                ("stretch", "Recovery"),
                ("walk", "Recovery"),
            ]

            var workoutIds: [Int] = []

            for (keyword, tagName) in workoutRules {
                if name.contains(keyword),
                   let id = tagId(named: tagName, from: workoutTags) {
                    workoutIds.append(id)
                }
            }

            if workoutIds.isEmpty,
               let fullBody = tagId(named: "Full Body", from: workoutTags) {
                workoutIds.append(fullBody)
            }

            workoutIds.prefix(2).forEach { selectedTagIds.insert($0) }

            // INSERT PIVOT ROWS — into the PIVOT table
            for tagId in selectedTagIds {
                try db.execute(
                    sql: """
                    INSERT INTO exercise_tag_pivots
                    (exercise_id, exercise_tag_id, created_at, updated_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    arguments: [exerciseId, tagId, Date(), Date()]
                )
            }
        }

        print("🔗 Seeded exercise_tag_pivots table.")
    }
}
