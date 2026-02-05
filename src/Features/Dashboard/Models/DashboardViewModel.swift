import Foundation
import Combine
import SwiftUI

final class DashboardViewModel: ObservableObject {
    enum DateRangeSelection: Equatable {
        case lifetime
        case custom(Date, Date)
    }

    @Published var dateSelection: DateRangeSelection = .lifetime
    @Published var showingDatePicker: Bool = false

    @Published var totalWeightLbs: Double = 0
    @Published var totalDistanceMiles: Double = 0
    @Published var totalDurationSec: Double = 0
    @Published var averageWorkoutsPerWeek: Double = 0

    private let sessionRepository: SessionRepository
    private(set) var userId: Int64

    init(sessionRepository: SessionRepository, userId: Int64) {
        self.sessionRepository = sessionRepository
        self.userId = userId
    }

    var dateRangeLabel: String {
        switch dateSelection {
        case .lifetime:
            return "Lifetime"
        case let .custom(start, end):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
    }

    @MainActor
    func loadDashboardData() async {
        do {
            let range: (Date?, Date?)
            switch dateSelection {
            case .lifetime:
                let earliest = try sessionRepository.earliestCompletedSessionDate(userId: userId)
                let start = earliest?.startOfDay
                let end = Date().endOfDay
                range = (start, end)
            case let .custom(start, end):
                range = (start.startOfDay, end.endOfDay)
            }
            let result = try sessionRepository.loadAggregates(userId: userId, start: range.0, end: range.1)
            self.totalWeightLbs = result.weightLbs
            self.totalDistanceMiles = result.distanceMiles
            self.totalDurationSec = result.durationSec

            // Compute average workouts per week based on selected date range
            let startDate: Date = range.0 ?? Date()
            let endDate: Date = range.1 ?? Date()

            let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
            let weeks = max(1.0, Double(days) / 7.0)
            // If SessionRepository supports session counts in aggregates, replace 0 below with that value.
            let completedWorkouts = try sessionRepository.countCompletedSessions(userId: userId, start: range.0, end: range.1)
            self.averageWorkoutsPerWeek = weeks > 0 ? Double(completedWorkouts) / weeks : 0

        } catch {
            print("[Dashboard] Failed to load aggregates:", error)
            self.totalWeightLbs = 0
            self.totalDistanceMiles = 0
            self.totalDurationSec = 0
            self.averageWorkoutsPerWeek = 0
        }
    }

    func formattedWeight(isImperial: Bool) -> (value: String, unit: String) {
        if isImperial {
            let val = totalWeightLbs
            return (val >= 100 ? String(format: "%.0f", val) : String(format: "%.1f", val), "lbs")
        } else {
            let kg = totalWeightLbs / 2.2046226218
            return (kg >= 100 ? String(format: "%.0f", kg) : String(format: "%.1f", kg), "kg")
        }
    }

    func formattedDistance(isImperial: Bool) -> (value: String, unit: String) {
        if isImperial {
            let val = totalDistanceMiles
            return (val >= 100 ? String(format: "%.0f", val) : String(format: "%.1f", val), "mi")
        } else {
            let km = totalDistanceMiles * 1.609344
            return (km >= 100 ? String(format: "%.0f", km) : String(format: "%.1f", km), "km")
        }
    }

    func formattedDuration() -> String {
        let totalSeconds = Int(totalDurationSec)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        var components: [String] = []
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 { components.append("\(minutes)m") }
        if seconds > 0 || components.isEmpty { components.append("\(seconds)s") }
        return components.joined(separator: " ")
    }
    
    func updateUser(id: Int64) {
        self.userId = id
    }

    func formattedWorkoutFrequency() -> (value: String, unit: String) {
        let val = averageWorkoutsPerWeek
        let valueStr = val >= 100 ? String(format: "%.0f", val) : String(format: "%.1f", val)
        return (valueStr, "/wk")
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }
}

