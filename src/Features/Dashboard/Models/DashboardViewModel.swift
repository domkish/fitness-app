import Foundation
import SwiftUI
import Combine

final class DashboardViewModel: ObservableObject {

    enum DateRangeSelection: Equatable {
        case lifetime
        case custom(Date, Date)
    }

    // MARK: - UI State

    @Published var dateSelection: DateRangeSelection = .custom(Calendar.current.date(byAdding: .day, value: -12, to: Date())!.startOfDay, Calendar.current.date(byAdding: .day, value: 1, to: Date())!.endOfDay)
    @Published var showingDatePicker = false

    @Published var totalWeightLbs: Double = 0
    @Published var totalDistanceMiles: Double = 0
    @Published var totalDurationSec: Double = 0
    @Published var averageWorkoutsPerWeek: Double = 0

    @Published var completedExercises: [ExerciseOption] = []
    @Published var selectedExerciseId: Int64? = nil
    @Published var prPoints: [SetsChartView.SetChartPoint] = []
    @Published var isLoadingExerciseLog = false
    @Published var exerciseLogError: String? = nil
    
    @Published var weightSeries: [Date: Double] = [:]
    @Published var bodyFatSeries: [Date: Double] = [:]
    @Published var hasWorkoutRoutines: Bool = false
    @Published var hasAnySessions: Bool = false

    // MARK: - Dependencies

    private let sessionRepository: SessionRepository
    private let calendarEntryRepository = CalendarEntryRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private(set) var userId: Int64

    // User creation date provider
    private let userCreatedAtProvider: () -> Date?
    private let isImperialProvider: () -> Bool

    init(sessionRepository: SessionRepository, userId: Int64, userCreatedAtProvider: @escaping () -> Date? = { nil }, isImperialProvider: @escaping () -> Bool = { true }) {
        self.sessionRepository = sessionRepository
        self.userId = userId
        self.userCreatedAtProvider = userCreatedAtProvider
        self.isImperialProvider = isImperialProvider
    }

    struct ExerciseOption: Identifiable, Hashable {
        let id: Int64
        let name: String
    }

    // MARK: - Date Helpers

    private func resolvedDateRange() throws -> (start: Date?, end: Date?) {
        switch dateSelection {
        case .lifetime:
            // Default window: today - 12 days to today + 1 day
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -12, to: now)?.startOfDay
            let end = Calendar.current.date(byAdding: .day, value: 1, to: now)?.endOfDay
            return (start, end)
        case let .custom(start, end):
            return (start.startOfDay, end.endOfDay)
        }
    }

    var dateRangeLabel: String {
        switch dateSelection {
        case .lifetime:
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now
            let end = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return "\(f.string(from: start)) – \(f.string(from: end))"
        case let .custom(start, end):
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
    }

    // MARK: - Dashboard Aggregates

    @MainActor
    func loadDashboardData() async {
        do {
            let range = try resolvedDateRange()

            let agg = try sessionRepository.loadAggregates(
                userId: userId,
                start: range.start,
                end: range.end
            )

            totalWeightLbs = agg.weightLbs
            totalDistanceMiles = agg.distanceMiles
            totalDurationSec = agg.durationSec

            let completed = try sessionRepository.countCompletedSessions(
                userId: userId,
                start: range.start,
                end: range.end
            )

            let days = max(
                1,
                Calendar.current.dateComponents(
                    [.day],
                    from: range.start ?? Date(),
                    to: range.end ?? Date()
                ).day ?? 1
            )

            averageWorkoutsPerWeek = Double(completed) / max(1, Double(days) / 7)
            
            if let start = range.start, let end = range.end {
                let id = userId
                let entries = try calendarEntryRepository.entries(in: start...end, userId: id)
                var w: [Date: Double] = [:]
                var bf: [Date: Double] = [:]
                for e in entries {
                    let day = CalendarEntry.date(from: e.date) ?? Date()
                    if let val = e.weight { w[day] = val }
                    if let val = e.bodyFat { bf[day] = val }
                }
                weightSeries = w
                bodyFatSeries = bf
            } else {
                weightSeries = [:]
                bodyFatSeries = [:]
            }

            // Determine if user has any workout routines and any sessions (regardless of date picker)
            do {
                let wr = WorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
                self.hasWorkoutRoutines = try wr.hasAnyWorkouts(for: userId)
            } catch {
                self.hasWorkoutRoutines = false
            }

            do {
                let count = try sessionRepository.countAnySessions(userId: userId)
                self.hasAnySessions = (count > 0)
            } catch {
                self.hasAnySessions = false
            }

        } catch {
            totalWeightLbs = 0
            totalDistanceMiles = 0
            totalDurationSec = 0
            averageWorkoutsPerWeek = 0
        }
    }

    // MARK: - Exercise Log

    @MainActor
    func loadExerciseLog() async {
        isLoadingExerciseLog = true
        exerciseLogError = nil

        do {
            let range = try resolvedDateRange()
            
            if let start = range.start, let end = range.end {
                let entries = try calendarEntryRepository.entries(in: start...end, userId: userId)
                var w: [Date: Double] = [:]
                var bf: [Date: Double] = [:]
                for e in entries {
                    let day = CalendarEntry.date(from: e.date) ?? Date()
                    if let val = e.weight { w[day] = val }
                    if let val = e.bodyFat { bf[day] = val }
                }
                weightSeries = w
                bodyFatSeries = bf
            } else {
                weightSeries = [:]
                bodyFatSeries = [:]
            }

            let exercises = try sessionRepository.fetchCompletedExercises(
                userId: userId,
                start: range.start,
                end: range.end
            )

            completedExercises = exercises.map {
                ExerciseOption(id: $0.id, name: $0.name)
            }

            if selectedExerciseId == nil {
                selectedExerciseId = completedExercises.first?.id
            }

            if let id = selectedExerciseId {
                await loadPRPoints(for: id)
            } else {
                prPoints = []
            }

        } catch {
            exerciseLogError = error.localizedDescription
            completedExercises = []
            prPoints = []
        }

        isLoadingExerciseLog = false
    }

    @MainActor
    func loadPRPoints(for exerciseId: Int64) async {
        do {
            let range = try resolvedDateRange()

            let points = try sessionRepository.fetchPRPoints(
                userId: userId,
                exerciseId: exerciseId,
                start: range.start,
                end: range.end
            )

            let imperial = isImperialProvider()
            let normalized = points.map { p -> (date: Date, value: Double, reps: Int, unit: String, isDuration: Bool) in
                let unitLower = p.unit.lowercased()
                if ["lbs", "kg"].contains(unitLower) {
                    if imperial {
                        let v = unitLower == "kg" ? (p.value * 2.2046226218) : p.value
                        return (p.date, v, p.reps, "lbs", false)
                    } else {
                        let v = unitLower == "lbs" ? (p.value / 2.2046226218) : p.value
                        return (p.date, v, p.reps, "kg", false)
                    }
                }
                if ["mi", "yd", "km", "m"].contains(unitLower) {
                    if imperial {
                        let miles: Double
                        switch unitLower {
                        case "mi": miles = p.value
                        case "yd": miles = p.value / 1760.0
                        case "km": miles = p.value / 1.609344
                        case "m":  miles = p.value / 1609.344
                        default: miles = p.value
                        }
                        return (p.date, miles, p.reps, "mi", false)
                    } else {
                        let km: Double
                        switch unitLower {
                        case "mi": km = p.value * 1.609344
                        case "yd": km = (p.value / 1760.0) * 1.609344
                        case "km": km = p.value
                        case "m":  km = p.value / 1000.0
                        default: km = p.value
                        }
                        return (p.date, km, p.reps, "km", false)
                    }
                }
                if unitLower == "none" {
                    // Use duration (minutes) on Y axis when unit is none
                    let minutes = Double(max(0, p.durationSec)) / 60.0
                    return (p.date, minutes, p.reps, "min", true)
                }
                // default: return unchanged
                return (p.date, p.value, p.reps, p.unit, false)
            }

            prPoints = normalized.enumerated().map { idx, p in
                SetsChartView.SetChartPoint(
                    date: p.date,
                    setIndex: idx,
                    value: p.value,
                    reps: p.reps,
                    unit: p.unit,
                    isPrevious: false
                )
            }

        } catch {
            prPoints = []
        }
    }

    func updateUser(id: Int64) {
        userId = id
    }

    // MARK: - Formatting

    func formattedWeight(isImperial: Bool) -> (value: String, unit: String) {
        let val = isImperial ? totalWeightLbs : totalWeightLbs / 2.2046226218
        return (String(format: "%.1f", val), isImperial ? "lbs" : "kg")
    }

    func formattedDistance(isImperial: Bool) -> (value: String, unit: String) {
        let val = isImperial ? totalDistanceMiles : totalDistanceMiles * 1.609344
        return (String(format: "%.1f", val), isImperial ? "mi" : "km")
    }

    func formattedDuration() -> String {
        let s = Int(totalDurationSec)
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    func formattedWorkoutFrequency() -> (value: String, unit: String) {
        (String(format: "%.1f", averageWorkoutsPerWeek), "/wk")
    }
    
    var prDateDomain: ClosedRange<Date>? {
        do {
            let range = try resolvedDateRange()
            if let start = range.start, let end = range.end { return start...end }
        } catch { }
        let dates = prPoints.compactMap { $0.date }
        if let minD = dates.min(), let maxD = dates.max() { return minD.startOfDay...maxD.endOfDay }
        return nil
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?
            .addingTimeInterval(-1) ?? self
    }
}

