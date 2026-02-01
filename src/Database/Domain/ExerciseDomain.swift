//
//  ExerciseModel.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import SwiftUI

struct ExerciseDomain: Identifiable, Codable {
    var id: Int64?
    var userId: Int
    var name: String
    var locked: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var tags: [ExerciseTagDomain] = []

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case locked
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case tags
    }

    init(from record: ExerciseRecord) {
        self.id = record.id
        self.userId = Int(record.userId)
        self.name = record.name
        self.locked = record.locked
        self.deletedAt = record.deletedAt
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }
}
