//
//  SessionDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation

struct SessionDomain {
    var id: Int64?
    var userId: Int64
    var workoutId: Int64
    var calendarWorkoutId: Int64
    var workoutName: String
    var totalDuration: Int
    var startedAt: Date?
    var completedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        userId: Int64,
        workoutId: Int64,
        calendarWorkoutId: Int64,
        workoutName: String,
        totalDuration: Int = 0,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.calendarWorkoutId = calendarWorkoutId
        self.workoutName = workoutName
        self.totalDuration = totalDuration
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
