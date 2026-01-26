//
//  ExerciseSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseSeeder {
    static func seed(db: Database) throws {
        // Only seed if table is empty (Laravel-style)
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM exercises") ?? 0
        guard count == 0 else { return }

        // Preset exercises from your Laravel seeder
        let exercises: [[String: Any]] = [
            // Core
            ["user_id": 0, "name": "Plank", "locked": true],
            ["user_id": 0, "name": "Side Plank", "locked": true],
            ["user_id": 0, "name": "Plank with Shoulder Tap", "locked": true],
            ["user_id": 0, "name": "Plank to Push-Up", "locked": true],

            ["user_id": 0, "name": "Sit-Up", "locked": true],
            ["user_id": 0, "name": "Decline Sit-Up", "locked": true],
            ["user_id": 0, "name": "Weighted Sit-Up", "locked": true],

            ["user_id": 0, "name": "Leg Raise", "locked": true],
            ["user_id": 0, "name": "Hanging Leg Raise", "locked": true],
            ["user_id": 0, "name": "Hanging Knee Raise", "locked": true],

            ["user_id": 0, "name": "Russian Twist", "locked": true],
            ["user_id": 0, "name": "Weighted Russian Twist", "locked": true],

            ["user_id": 0, "name": "Bicycle Crunch", "locked": true],
            ["user_id": 0, "name": "Mountain Climbers", "locked": true],
            ["user_id": 0, "name": "V-Up", "locked": true],
            ["user_id": 0, "name": "Ab Rollout", "locked": true],

            // Abs
            ["user_id": 0, "name": "Crunch", "locked": true],
            ["user_id": 0, "name": "Weighted Crunch", "locked": true],
            ["user_id": 0, "name": "Cable Crunch", "locked": true],
            ["user_id": 0, "name": "Reverse Crunch", "locked": true],

            ["user_id": 0, "name": "Dumbbell Side Bend", "locked": true],
            ["user_id": 0, "name": "Cable Oblique Crunch", "locked": true],
            ["user_id": 0, "name": "Cable Woodchopper", "locked": true],
            ["user_id": 0, "name": "Hanging Oblique Raise", "locked": true],

            // Arms
            ["user_id": 0, "name": "Dumbbell Curl", "locked": true],
            ["user_id": 0, "name": "Barbell Curl", "locked": true],
            ["user_id": 0, "name": "Hammer Curl", "locked": true],
            ["user_id": 0, "name": "Incline Dumbbell Curl", "locked": true],
            ["user_id": 0, "name": "Preacher Curl", "locked": true],
            ["user_id": 0, "name": "Zottman Curl", "locked": true],
            ["user_id": 0, "name": "Cable Curl", "locked": true],

            ["user_id": 0, "name": "Tricep Dip", "locked": true],
            ["user_id": 0, "name": "Bench Dip", "locked": true],
            ["user_id": 0, "name": "Skull Crusher", "locked": true],
            ["user_id": 0, "name": "Close-Grip Bench Press", "locked": true],
            ["user_id": 0, "name": "Overhead Tricep Extension", "locked": true],
            ["user_id": 0, "name": "Cable Tricep Pushdown", "locked": true],
            ["user_id": 0, "name": "Diamond Push-Up", "locked": true],

            // Back
            ["user_id": 0, "name": "Pull-Up", "locked": true],
            ["user_id": 0, "name": "Chin-Up", "locked": true],
            ["user_id": 0, "name": "Wide-Grip Pull-Up", "locked": true],
            ["user_id": 0, "name": "Neutral-Grip Pull-Up", "locked": true],

            ["user_id": 0, "name": "Lat Pulldown", "locked": true],
            ["user_id": 0, "name": "Close-Grip Lat Pulldown", "locked": true],

            ["user_id": 0, "name": "Bent Over Row", "locked": true],
            ["user_id": 0, "name": "Barbell Row", "locked": true],
            ["user_id": 0, "name": "Dumbbell Row", "locked": true],
            ["user_id": 0, "name": "Seated Cable Row", "locked": true],
            ["user_id": 0, "name": "T-Bar Row", "locked": true],

            // Chest
            ["user_id": 0, "name": "Bench Press", "locked": true],
            ["user_id": 0, "name": "Flat Dumbbell Bench Press", "locked": true],
            ["user_id": 0, "name": "Incline Bench Press", "locked": true],
            ["user_id": 0, "name": "Incline Dumbbell Bench Press", "locked": true],
            ["user_id": 0, "name": "Decline Bench Press", "locked": true],

            ["user_id": 0, "name": "Push-Up", "locked": true],
            ["user_id": 0, "name": "Wide Push-Up", "locked": true],
            ["user_id": 0, "name": "Incline Push-Up", "locked": true],
            ["user_id": 0, "name": "Decline Push-Up", "locked": true],

            ["user_id": 0, "name": "Chest Fly", "locked": true],
            ["user_id": 0, "name": "Dumbbell Fly", "locked": true],
            ["user_id": 0, "name": "Cable Fly", "locked": true],

            // Legs
            ["user_id": 0, "name": "Squat", "locked": true],
            ["user_id": 0, "name": "Back Squat", "locked": true],
            ["user_id": 0, "name": "Front Squat", "locked": true],
            ["user_id": 0, "name": "Goblet Squat", "locked": true],
            ["user_id": 0, "name": "Box Squat", "locked": true],
            ["user_id": 0, "name": "Speed Squat", "locked": true],

            ["user_id": 0, "name": "Lunge", "locked": true],
            ["user_id": 0, "name": "Walking Lunge", "locked": true],
            ["user_id": 0, "name": "Reverse Lunge", "locked": true],
            ["user_id": 0, "name": "Bulgarian Split Squat", "locked": true],

            ["user_id": 0, "name": "Deadlift", "locked": true],
            ["user_id": 0, "name": "Romanian Deadlift", "locked": true],
            ["user_id": 0, "name": "Sumo Deadlift", "locked": true],
            ["user_id": 0, "name": "Trap Bar Deadlift", "locked": true],

            ["user_id": 0, "name": "Leg Press", "locked": true],
            ["user_id": 0, "name": "Calf Raise", "locked": true],
            ["user_id": 0, "name": "Seated Calf Raise", "locked": true],

            // Shoulders
            ["user_id": 0, "name": "Overhead Press", "locked": true],
            ["user_id": 0, "name": "Barbell Overhead Press", "locked": true],
            ["user_id": 0, "name": "Dumbbell Shoulder Press", "locked": true],
            ["user_id": 0, "name": "Arnold Press", "locked": true],

            ["user_id": 0, "name": "Lateral Raise", "locked": true],
            ["user_id": 0, "name": "Front Raise", "locked": true],
            ["user_id": 0, "name": "Rear Delt Fly", "locked": true],
            ["user_id": 0, "name": "Face Pull", "locked": true],

            // Full Body
            ["user_id": 0, "name": "Burpee", "locked": true],
            ["user_id": 0, "name": "Burpee Box Jump", "locked": true],

            ["user_id": 0, "name": "Clean and Press", "locked": true],
            ["user_id": 0, "name": "Power Clean", "locked": true],
            ["user_id": 0, "name": "Hang Clean", "locked": true],

            ["user_id": 0, "name": "Snatch", "locked": true],
            ["user_id": 0, "name": "Power Snatch", "locked": true],
            ["user_id": 0, "name": "Hang Snatch", "locked": true],

            // Cardio
            ["user_id": 0, "name": "Walking", "locked": true],
            ["user_id": 0, "name": "Incline Walking", "locked": true],
            ["user_id": 0, "name": "Running", "locked": true],
            ["user_id": 0, "name": "Sprint", "locked": true],
            ["user_id": 0, "name": "Cycling", "locked": true],
            ["user_id": 0, "name": "Rowing", "locked": true],
            ["user_id": 0, "name": "Jump Rope", "locked": true],

            // Other
            ["user_id": 0, "name": "Farmer's Carry", "locked": true],
            ["user_id": 0, "name": "Single-Arm Farmer's Carry", "locked": true],
            ["user_id": 0, "name": "Battle Ropes", "locked": true],
            ["user_id": 0, "name": "TRX Rows", "locked": true],
            ["user_id": 0, "name": "Sled Push", "locked": true],
            ["user_id": 0, "name": "Sled Pull", "locked": true],
        ]

        // Insert exercises
        for exercise in exercises {
            try db.execute(
                sql: """
                INSERT INTO exercises (user_id, name, locked, created_at, updated_at)
                VALUES (:user_id, :name, :locked, :created_at, :updated_at)
                """,
                arguments: [
                    "user_id": exercise["user_id"] as! Int,
                    "name": exercise["name"] as! String,
                    "locked": exercise["locked"] as! Bool,
                    "created_at": Date(),
                    "updated_at": Date()
                ]
            )
        }

        print("📝 Seeded exercises table with \(exercises.count) records.")
    }
}

