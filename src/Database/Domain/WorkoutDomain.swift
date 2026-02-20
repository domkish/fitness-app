//
//  WorkoutDomain.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/27/26.
//
import SwiftUI

struct WorkoutDomain: Identifiable, Codable {
    var id: Int64?
    var userId: Int
    var name: String
    var color: String
    var description: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    // If workouts will have tags, you can add a domain type similar to ExerciseTagDomain and uncomment below:
    // var tags: [WorkoutTagDomain] = []

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case color
        case description
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // case tags
    }

    init(from record: WorkoutRecord) {
        self.id = record.id
        self.userId = Int(record.userId)
        self.name = record.name
        self.color = record.color
        self.description = record.description
        self.deletedAt = record.deletedAt
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }

    init(id: Int64? = nil, userId: Int, name: String, color: String, description: String? = nil, deletedAt: Date? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.description = description
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
