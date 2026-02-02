//
//  UnitRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

final class UnitRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAll() throws -> [UnitDomain] {
        try dbQueue.read { db in
            try UnitRecord
                .fetchAll(db)
                .map { UnitDomain(from: $0) } // Record → Domain
        }
    }

    func fetchByType(_ type: Int) throws -> [UnitDomain] {
        try dbQueue.read { db in
            try UnitRecord
                .filter(UnitRecord.Columns.type == type)
                .fetchAll(db)
                .map { UnitDomain(from: $0) }
        }
    }

    func createOrUpdate(_ unit: UnitDomain) throws {
        try dbQueue.write { db in
            let record = UnitRecord(from: unit)
            try record.insert(db, onConflict: .replace)
        }
    }

    func delete(_ unit: UnitDomain) throws {
        try dbQueue.write { db in
            if let id = unit.id {
                _ = try UnitRecord.deleteOne(db, key: id)
            }
        }
    }
}

