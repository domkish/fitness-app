//
//  ExerciseTagDomain.swift
//  SimplyFitness
//  Domain/ExerciseTagDoman
//
//  Created by Dominic Kish on 1/26/26.
//
import Foundation

/// Single source of truth for Exercise Tag domain model.
struct ExerciseTagDomain: Equatable, Hashable, Codable {
    enum Kind: String, Codable {
        case group
        case category
        case workout
        case unknown

        init(fromRaw raw: String) {
            switch raw.lowercased() {
            case "group": self = .group
            case "category": self = .category
            case "workout": self = .workout
            default: self = .unknown
            }
        }
    }

    var id: Int64?
    var name: String
    /// Backing storage as saved in the database (e.g., "Group", "Category", "Workout")
    var type: String
    var createdAt: Date
    var updatedAt: Date

    /// Convenience accessor used by UI code
    var kind: Kind { Kind(fromRaw: type) }
}

