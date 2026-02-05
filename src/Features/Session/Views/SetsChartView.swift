//
//  SetsChartView.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/2/26.
//
import SwiftUI
import Charts

struct SetsChartView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let points: [SetChartPoint]
    let xDomain: ClosedRange<Date>?

    init(points: [SetChartPoint], xDomain: ClosedRange<Date>? = nil) {
        self.points = points
        self.xDomain = xDomain
    }

    @State private var selectedPointID: UUID?
    @State private var tooltipPosition: CGPoint = .zero

    var body: some View {
        ZStack {
            chartBody
            tooltipOverlay
        }
        .frame(height: 220)
        .padding(.vertical, 8)
        .animation(.easeInOut, value: selectedPointID)
    }

    // MARK: - Chart content
    @ViewBuilder
    private var chartBody: some View {
        if let xDomain = xDomain {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date ?? Date(timeIntervalSince1970: 0)),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.isPrevious ? themeManager.currentTheme.secondary : themeManager.currentTheme.primary)
                .symbol(point.isPrevious ? .diamond : .circle)
                .symbolSize(80)
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yAxisRange)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                    AxisValueLabel(format: .dateTime.month().day())
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                }
            }
            .chartYAxis {
                AxisMarks(values: yAxisTicks) { value in
                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                    AxisValueLabel().foregroundStyle(themeManager.currentTheme.textDefault)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let tapLocation = value.location
                                    if let xDate: Date = proxy.value(atX: tapLocation.x),
                                       let yValue: Double = proxy.value(atY: tapLocation.y) {
                                        if let nearest = points.min(by: {
                                            let dx0 = ($0.date ?? .distantPast).timeIntervalSince1970
                                            let dx1 = ($1.date ?? .distantPast).timeIntervalSince1970
                                            let dt = abs(dx0 - xDate.timeIntervalSince1970)
                                            let dv0 = abs($0.value - yValue)
                                            let dv1 = abs($1.value - yValue)
                                            return (dt + dv0) < (dt + dv1)
                                        }) {
                                            selectedPointID = nearest.id
                                            if let nodeX = (nearest.date != nil ? proxy.position(forX: nearest.date!) : nil),
                                               let nodeY = proxy.position(forY: nearest.value) {
                                                tooltipPosition = CGPoint(x: nodeX, y: nodeY)
                                            }
                                        }
                                    }
                                }
                        )
                }
            }
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Set", point.setIndex),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.isPrevious ? themeManager.currentTheme.secondary : themeManager.currentTheme.primary)
                .symbol(point.isPrevious ? .diamond : .circle)
                .symbolSize(80)
            }
            .chartXScale(domain: 0...(totalSets + 1))
            .chartYScale(domain: yAxisRange)
            .chartXAxis {
                AxisMarks(values: limitedIndexTicks) { value in
                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                    AxisValueLabel().foregroundStyle(themeManager.currentTheme.textDefault)
                }
            }
            .chartYAxis {
                AxisMarks(values: yAxisTicks) { value in
                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                    AxisValueLabel().foregroundStyle(themeManager.currentTheme.textDefault)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let tapLocation = value.location
                                    if let xValue: Double = proxy.value(atX: tapLocation.x),
                                       let yValue: Double = proxy.value(atY: tapLocation.y) {
                                        if let nearest = points.min(by: {
                                            abs(Double($0.setIndex) - xValue) + abs($0.value - yValue) <
                                            abs(Double($1.setIndex) - xValue) + abs($1.value - yValue)
                                        }) {
                                            selectedPointID = nearest.id
                                            if let nodeX = proxy.position(forX: nearest.setIndex),
                                               let nodeY = proxy.position(forY: nearest.value) {
                                                tooltipPosition = CGPoint(x: nodeX, y: nodeY)
                                            }
                                        }
                                    }
                                }
                        )
                }
            }
        }
    }

    // MARK: - Tooltip under node
    @ViewBuilder
    private var tooltipOverlay: some View {
        if let selected = points.first(where: { $0.id == selectedPointID }) {
            let mainLine: String = (selected.reps == 1 ? "\(Int(selected.value)) \(selected.unit)" : "\(Int(selected.value)) \(selected.unit) x \(selected.reps) reps")
            Text(mainLine)
                .font(.caption)
                .padding(8)
                .background(themeManager.currentTheme.surface)
                .foregroundColor(themeManager.currentTheme.primary)
                .cornerRadius(8)
                .shadow(radius: 4)
                .position(x: tooltipPosition.x,
                          y: tooltipPosition.y + 30)
                .transition(.scale.combined(with: .opacity))
                .onTapGesture {
                    selectedPointID = nil
                }
        }
    }


    // MARK: - Computed properties
    private var totalSets: Int {
        points.map { $0.setIndex }.max() ?? 0
    }

    private var yAxisRange: ClosedRange<Double> {
        guard let minValue = points.map({ $0.value }).min(),
              let maxValue = points.map({ $0.value }).max() else {
            // Default domain if no data
            return 0...100
        }

        // Start from a small padding and snap to multiples of 5
        let baseStep: Double = 5
        let paddedMin = minValue - baseStep / 2
        let paddedMax = maxValue + baseStep / 2
        let lower = floor(paddedMin / baseStep) * baseStep
        let upper = ceil(paddedMax / baseStep) * baseStep

        // Ensure non-degenerate domain
        if lower == upper {
            return (lower - baseStep)...(upper + baseStep)
        }
        return lower...upper
    }

    private var yAxisTicks: [Double] {
        let lower = yAxisRange.lowerBound
        let upper = yAxisRange.upperBound
        let span = max(upper - lower, 0)

        // Choose a step (multiple of 5) such that tick count <= 10
        let baseStep: Double = 5
        let maxTicks = 10.0

        // Start with base step and increase until we get <= 10 ticks
        var step = baseStep
        if span > 0 {
            let initialCount = span / step
            if initialCount > maxTicks {
                // Increase step by factors of 2 until the tick count is within limit
                // (keeping it a multiple of 5)
                var factor: Double = 1
                while (span / (baseStep * factor)) > maxTicks {
                    factor *= 2
                }
                step = baseStep * factor
            }
        }

        // Snap lower/upper to the chosen step to align ticks nicely
        let snappedLower = (lower / step).rounded(.down) * step
        let snappedUpper = (upper / step).rounded(.up) * step

        // Generate the ticks
        var ticks: [Double] = []
        var v = snappedLower
        while v <= snappedUpper + 1e-9 { // small epsilon to include upper bound
            ticks.append(v)
            v += step
        }
        return ticks
    }

    private var limitedIndexTicks: [Int] {
        let maxTicks = 5
        let lower = 0
        let upper = totalSets + 1
        let span = max(upper - lower, 0)
        guard span > 0 else { return [lower] }
        if span + 1 <= maxTicks { // already within limit when using every integer
            return Array(lower...upper)
        }
        // Compute step to yield at most maxTicks marks, always at least 1
        let step = max(1, Int(ceil(Double(span) / Double(maxTicks - 1))))
        var ticks: [Int] = []
        var v = lower
        while v < upper {
            ticks.append(v)
            v += step
        }
        if ticks.last != upper { ticks.append(upper) }
        return ticks
    }

    // MARK: - Nested chart model
    struct SetChartPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date?
        let setIndex: Int
        let value: Double
        let reps: Int
        let unit: String
        let isPrevious: Bool
    }
}

