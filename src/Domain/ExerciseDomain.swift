//
//  ExerciseModel.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import SwiftUI

struct ExerciseDomain: Identifiable {
    var id: Int64?
    var userId: Int
    var name: String
    var locked: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

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
