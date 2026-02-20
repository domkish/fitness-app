//
//  CalendarViewModel.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/4/26.
//
import Foundation
import Combine
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {

    enum Mode {
        case day, week, month
    }

    // MARK: - Published State

    @Published var mode: Mode = .day
    @Published var selectedDayDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Dependencies

    let calendarRepo: CalendarEntryRepository

    // MARK: - Init

    init(
        calendarRepo: CalendarEntryRepository = CalendarEntryRepository(
            dbQueue: DatabaseQueueProvider.shared.dbQueue
        )
    ) {
        self.calendarRepo = calendarRepo
    }

    // MARK: - Intents

    func selectMode(_ mode: Mode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.mode = mode
        }
    }

    func selectDate(_ date: Date) {
        selectedDayDate = Calendar.current.startOfDay(for: date)
        mode = .day
    }
}

