//
//  UnitDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import SwiftUI


struct UnitDomain: Identifiable {
    var id: Int64?
    var type: Int?          // 1 = imperial, 0 = metric
    var name: String
    var abbreviation: String
    var createdAt: Date
    var updatedAt: Date

    init(from record: UnitRecord) {
        self.id = record.id
        self.type = record.type
        self.name = record.name
        self.abbreviation = record.abbreviation
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }
}
