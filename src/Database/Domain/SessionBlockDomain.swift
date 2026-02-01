//
//  SessionExerciseDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation

struct SessionBlockDomain {
    var id: Int64?
    var sessionId: Int64
    var workoutBlockId: Int64
    var duration: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        sessionId: Int64,
        workoutBlockId: Int64,
        duration: Int = 0,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.workoutBlockId = workoutBlockId
        self.duration = duration
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
