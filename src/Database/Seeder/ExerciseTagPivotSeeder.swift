//
//  ExerciseTagPivotSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

import Foundation

struct ExerciseTagPivotSeeder {

    struct TagAssignment {
        let groups: [String]
        let categories: [String]
        let workouts: [String]
    }

    static func seed(db: Database) throws {

        let count = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM exercise_tag_pivots"
        ) ?? 0
        guard count == 0 else { return }

        // Fetch exercises
        let exercises = try Row.fetchAll(db, sql: "SELECT id, name FROM exercises")
        let exerciseMap = Dictionary(
            uniqueKeysWithValues: exercises.map { ($0["name"] as String, $0["id"] as Int) }
        )

        // Fetch tags
        let tags = try Row.fetchAll(db, sql: "SELECT id, name, type FROM exercise_tags")
        let tagMap = Dictionary(
            uniqueKeysWithValues: tags.map { ("\($0["type"] as String)|\($0["name"] as String)", $0["id"] as Int) }
        )

        // ============================
        // Explicit, reasoned assignments
        // ============================
        let assignments: [String: TagAssignment] = [

            // -------- Core / Abs --------
            "Plank": TagAssignment(groups: ["Core"], categories: ["Bodyweight"], workouts: ["Full Body", "Recovery"]),
            "Side Plank": TagAssignment(groups: ["Core"], categories: ["Bodyweight"], workouts: ["Full Body", "Recovery"]),
            "Plank with Shoulder Tap": TagAssignment(groups: ["Core"], categories: ["Bodyweight"], workouts: ["Full Body", "Recovery"]),
            "Plank to Push-Up": TagAssignment(groups: ["Core"], categories: ["Bodyweight"], workouts: ["Full Body", "Push"]),
            "Sit-Up": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Decline Sit-Up": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Weighted Sit-Up": TagAssignment(groups: ["Abs"], categories: ["Dumbbell"], workouts: ["Full Body"]),
            "Leg Raise": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Hanging Leg Raise": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Hanging Knee Raise": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Russian Twist": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Weighted Russian Twist": TagAssignment(groups: ["Abs"], categories: ["Dumbbell"], workouts: ["Full Body"]),
            "Bicycle Crunch": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Mountain Climbers": TagAssignment(groups: ["Core"], categories: ["Bodyweight"], workouts: ["Full Body", "Cardio"]),
            "V-Up": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Ab Rollout": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Crunch": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Weighted Crunch": TagAssignment(groups: ["Abs"], categories: ["Dumbbell"], workouts: ["Full Body"]),
            "Cable Crunch": TagAssignment(groups: ["Abs"], categories: ["Machine"], workouts: ["Full Body"]),
            "Reverse Crunch": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Dumbbell Side Bend": TagAssignment(groups: ["Abs"], categories: ["Dumbbell"], workouts: ["Upper Body"]),
            "Cable Oblique Crunch": TagAssignment(groups: ["Abs"], categories: ["Machine"], workouts: ["Full Body"]),
            "Cable Woodchopper": TagAssignment(groups: ["Abs"], categories: ["Machine"], workouts: ["Full Body"]),
            "Hanging Oblique Raise": TagAssignment(groups: ["Abs"], categories: ["Bodyweight"], workouts: ["Full Body"]),

            // -------- Arms / Biceps / Triceps --------
            "Dumbbell Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Barbell Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Barbell"], workouts: ["Pull"]),
            "Hammer Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Incline Dumbbell Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Preacher Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Barbell"], workouts: ["Pull"]),
            "Zottman Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Cable Curl": TagAssignment(groups: ["Arms", "Biceps"], categories: ["Machine"], workouts: ["Pull"]),
            "Tricep Dip": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Bench Dip": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Skull Crusher": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Barbell"], workouts: ["Push"]),
            "Close-Grip Bench Press": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Barbell"], workouts: ["Push"]),
            "Overhead Tricep Extension": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Cable Tricep Pushdown": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Machine"], workouts: ["Push"]),
            "Diamond Push-Up": TagAssignment(groups: ["Arms", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),

            // -------- Back --------
            "Pull-Up": TagAssignment(groups: ["Back", "Biceps"], categories: ["Bodyweight"], workouts: ["Pull"]),
            "Chin-Up": TagAssignment(groups: ["Back", "Biceps"], categories: ["Bodyweight"], workouts: ["Pull"]),
            "Wide-Grip Pull-Up": TagAssignment(groups: ["Back", "Biceps"], categories: ["Bodyweight"], workouts: ["Pull"]),
            "Neutral-Grip Pull-Up": TagAssignment(groups: ["Back", "Biceps"], categories: ["Bodyweight"], workouts: ["Pull"]),
            "Lat Pulldown": TagAssignment(groups: ["Back"], categories: ["Machine"], workouts: ["Pull"]),
            "Close-Grip Lat Pulldown": TagAssignment(groups: ["Back"], categories: ["Machine"], workouts: ["Pull"]),
            "Bent Over Row": TagAssignment(groups: ["Back"], categories: ["Barbell"], workouts: ["Pull"]),
            "Barbell Row": TagAssignment(groups: ["Back"], categories: ["Barbell"], workouts: ["Pull"]),
            "Dumbbell Row": TagAssignment(groups: ["Back"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Seated Cable Row": TagAssignment(groups: ["Back"], categories: ["Machine"], workouts: ["Pull"]),
            "T-Bar Row": TagAssignment(groups: ["Back"], categories: ["Barbell"], workouts: ["Pull"]),

            // -------- Chest --------
            "Bench Press": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Barbell"], workouts: ["Push", "Upper Body"]),
            "Flat Dumbbell Bench Press": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Incline Bench Press": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Barbell"], workouts: ["Push"]),
            "Incline Dumbbell Bench Press": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Decline Bench Press": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Barbell"], workouts: ["Push"]),
            "Push-Up": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Wide Push-Up": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Incline Push-Up": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Decline Push-Up": TagAssignment(groups: ["Chest", "Triceps"], categories: ["Bodyweight"], workouts: ["Push"]),
            "Chest Fly": TagAssignment(groups: ["Chest"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Dumbbell Fly": TagAssignment(groups: ["Chest"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Cable Fly": TagAssignment(groups: ["Chest"], categories: ["Machine"], workouts: ["Push"]),

            // -------- Legs --------
            "Squat": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Back Squat": TagAssignment(groups: ["Legs"], categories: ["Barbell"], workouts: ["Leg"]),
            "Front Squat": TagAssignment(groups: ["Legs"], categories: ["Barbell"], workouts: ["Leg"]),
            "Goblet Squat": TagAssignment(groups: ["Legs"], categories: ["Dumbbell"], workouts: ["Leg"]),
            "Box Squat": TagAssignment(groups: ["Legs"], categories: ["Barbell"], workouts: ["Leg"]),
            "Speed Squat": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Lunge": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Walking Lunge": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Reverse Lunge": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Bulgarian Split Squat": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Deadlift": TagAssignment(groups: ["Legs", "Back"], categories: ["Barbell"], workouts: ["Pull", "Leg"]),
            "Romanian Deadlift": TagAssignment(groups: ["Legs", "Back"], categories: ["Barbell"], workouts: ["Pull", "Leg"]),
            "Sumo Deadlift": TagAssignment(groups: ["Legs", "Back"], categories: ["Barbell"], workouts: ["Pull", "Leg"]),
            "Trap Bar Deadlift": TagAssignment(groups: ["Legs", "Back"], categories: ["Barbell"], workouts: ["Pull", "Leg"]),
            "Leg Press": TagAssignment(groups: ["Legs"], categories: ["Machine"], workouts: ["Leg"]),
            "Calf Raise": TagAssignment(groups: ["Legs"], categories: ["Bodyweight"], workouts: ["Leg"]),
            "Seated Calf Raise": TagAssignment(groups: ["Legs"], categories: ["Machine"], workouts: ["Leg"]),

            // -------- Shoulders --------
            "Overhead Press": TagAssignment(groups: ["Shoulders"], categories: ["Barbell"], workouts: ["Push"]),
            "Barbell Overhead Press": TagAssignment(groups: ["Shoulders"], categories: ["Barbell"], workouts: ["Push"]),
            "Dumbbell Shoulder Press": TagAssignment(groups: ["Shoulders"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Arnold Press": TagAssignment(groups: ["Shoulders"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Lateral Raise": TagAssignment(groups: ["Shoulders"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Front Raise": TagAssignment(groups: ["Shoulders"], categories: ["Dumbbell"], workouts: ["Push"]),
            "Rear Delt Fly": TagAssignment(groups: ["Shoulders"], categories: ["Dumbbell"], workouts: ["Pull"]),
            "Face Pull": TagAssignment(groups: ["Shoulders"], categories: ["Machine"], workouts: ["Pull"]),

            // -------- Full Body --------
            "Burpee": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body", "Cardio"]),
            "Burpee Box Jump": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body", "Cardio"]),
            "Clean and Press": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),
            "Power Clean": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),
            "Hang Clean": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),
            "Snatch": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),
            "Power Snatch": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),
            "Hang Snatch": TagAssignment(groups: ["Full Body"], categories: ["Barbell"], workouts: ["Full Body"]),

            // -------- Cardio --------
            "Walking": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Incline Walking": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Running": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Sprint": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Cycling": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Rowing": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),
            "Jump Rope": TagAssignment(groups: ["Cardio"], categories: ["Duration"], workouts: ["Cardio"]),

            // -------- Other --------
            "Farmer's Carry": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Single-Arm Farmer's Carry": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Battle Ropes": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body", "Cardio"]),
            "TRX Rows": TagAssignment(groups: ["Back"], categories: ["Bodyweight"], workouts: ["Pull"]),
            "Sled Push": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body"]),
            "Sled Pull": TagAssignment(groups: ["Full Body"], categories: ["Bodyweight"], workouts: ["Full Body"])
        ]

        // ============================
        // Insert pivot records
        // ============================
        for (exerciseName, assignment) in assignments {

            guard let exerciseId = exerciseMap[exerciseName] else {
                fatalError("❌ Exercise not found: \(exerciseName)")
            }

            try insert(db, exerciseId, assignment.groups, "Group", tagMap)
            try insert(db, exerciseId, assignment.categories, "Category", tagMap)
            try insert(db, exerciseId, assignment.workouts, "Workout", tagMap)
        }

        print("🔗 Seeded exercise_tag_pivots table.")
    }

    private static func insert(
        _ db: Database,
        _ exerciseId: Int,
        _ tagNames: [String],
        _ type: String,
        _ tagMap: [String: Int]
    ) throws {

        guard !tagNames.isEmpty else {
            fatalError("❌ No \(type) tag for exercise_id \(exerciseId)")
        }

        guard tagNames.count <= 2 else {
            fatalError("❌ \(type) must have at most 2 tags")
        }

        for name in tagNames {
            guard let tagId = tagMap["\(type)|\(name)"] else {
                fatalError("❌ Tag not found: \(type)|\(name)")
            }

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
}
