//
//  TaskDomain.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/29/26.
//

import Foundation
public struct TaskDomain: Identifiable, Hashable, Sendable {
    public var id: Int64?
    public var userId: Int64? // optional until repository wired
    public var name: String
    public var sunday: Bool
    public var monday: Bool
    public var tuesday: Bool
    public var wednesday: Bool
    public var thursday: Bool
    public var friday: Bool
    public var saturday: Bool
    public var startedAt: Date?
    public var endsAt: Date?
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var color: String? // optional UI tint, aligns with WorkoutView pattern

    public init(
        id: Int64? = nil,
        userId: Int64? = nil,
        name: String,
        sunday: Bool = false,
        monday: Bool = false,
        tuesday: Bool = false,
        wednesday: Bool = false,
        thursday: Bool = false,
        friday: Bool = false,
        saturday: Bool = false,
        startedAt: Date? = nil,
        endsAt: Date? = nil,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        color: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.sunday = sunday
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.color = color
    }
    
    public var isActiveToday: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return false
        }
    }
    
    public static func placeholder(id: Int64, name: String) -> TaskDomain {
        TaskDomain(
            id: id,
            userId: nil,
            name: name,
            sunday: false,
            monday: false,
            tuesday: false,
            wednesday: false,
            thursday: false,
            friday: false,
            saturday: false,
            startedAt: nil,
            endsAt: nil,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            color: nil
        )
    }
}

