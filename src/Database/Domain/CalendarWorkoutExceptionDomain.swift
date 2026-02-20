//
//  CalendarWorkoutExceptionDomain.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/4/26.
//
import Foundation

struct CalendarWorkoutException: Identifiable, Sendable, Equatable {
    var id: Int64?
    
    var calendarWorkoutId: Int64
    var date: Date // normalized day value
    
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    
    init(id: Int64? = nil, calendarWorkoutId: Int64, date: Date, createdAt: Date = Date(), updatedAt: Date = Date(), deletedAt: Date? = nil) {
        self.id = id
        self.calendarWorkoutId = calendarWorkoutId
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

extension CalendarWorkoutException: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        
        case calendarWorkoutId = "calendar_workout_id"
        case date
        
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

