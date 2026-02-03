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

    @State private var selectedPointID: UUID?
    @State private var tooltipPosition: CGPoint = .zero

    var body: some View {
        ZStack {
            chartBody
            tooltipOverlay
            sessionPROverlay
                .padding(.trailing, 24)
                .padding(.bottom, 20)
        }
        .frame(height: 220)
        .padding(.vertical, 8)
        .animation(.easeInOut, value: selectedPointID)
    }

    // MARK: - Chart content
    private var chartBody: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Set", point.setIndex),
                y: .value("Value", point.value)
            )
            .foregroundStyle(point.isPrevious ? themeManager.currentTheme.secondary : themeManager.currentTheme.primary)
            .symbol(point.isPrevious ? .diamond : .circle)
            .symbolSize(80)
        }
        // X-axis: 0 → total sets + 1
        .chartXScale(domain: 0...(totalSets + 1))
        .chartYScale(domain: yAxisRange)
        .chartXAxis {
            AxisMarks(values: Array(0...totalSets + 1)) { value in
                AxisGridLine()
                    .foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                AxisTick()
                    .foregroundStyle(themeManager.currentTheme.textDefault)
                AxisValueLabel()
                    .foregroundStyle(themeManager.currentTheme.textDefault)
            }
        }
        .chartYAxis {
            AxisMarks(values: yAxisTicks) { value in
                AxisGridLine()
                    .foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                AxisTick()
                    .foregroundStyle(themeManager.currentTheme.textDefault)
                AxisValueLabel()
                    .foregroundStyle(themeManager.currentTheme.textDefault)
            }
        }
        // MARK: - Tap overlay
        .chartOverlay { proxy in
            GeometryReader { geo in
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

    // MARK: - Tooltip under node
    @ViewBuilder
    private var tooltipOverlay: some View {
        if let selected = points.first(where: { $0.id == selectedPointID }) {
            VStack(spacing: 4) {
                Text("\(Int(selected.value)) \(selected.unit) x \(selected.reps) reps")
                    .font(.caption)
                    .padding(8)
                    .background(themeManager.currentTheme.surface)
                    .foregroundColor(themeManager.currentTheme.primary)
                    .cornerRadius(8)
                    .shadow(radius: 4)

                Text(selected.isPrevious ? "Previous set" : "Current set")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
            .position(x: tooltipPosition.x,
                      y: tooltipPosition.y + 30)
            .transition(.scale.combined(with: .opacity))
            .onTapGesture {
                selectedPointID = nil
            }
        }
    }

    @ViewBuilder
    private var sessionPROverlay: some View {
        if let pr = sessionPR {
            VStack(alignment: .center, spacing: 4) {
                Text("Session PR")
                    .font(.caption.bold())
                    .foregroundColor(themeManager.currentTheme.primary)
                    .padding(.horizontal)
                Text("\(Int(pr.value)) \(pr.unit) x \(pr.reps) reps")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.horizontal)
            }
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .border(themeManager.currentTheme.borderDefault)
            .cornerRadius(8)
            .padding([.trailing, .bottom], 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: - Computed properties
    private var totalSets: Int {
        points.map { $0.setIndex }.max() ?? 0
    }

    private var sessionPR: SetChartPoint? {
        guard !points.isEmpty else { return nil }
        return points.sorted {
            if $0.value != $1.value {
                return $0.value > $1.value
            } else {
                return $0.reps > $1.reps
            }
        }.first
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

    // MARK: - Nested chart model
    struct SetChartPoint: Identifiable, Equatable {
        let id = UUID()
        let setIndex: Int
        let value: Double
        let reps: Int
        let unit: String
        let isPrevious: Bool
    }
}
