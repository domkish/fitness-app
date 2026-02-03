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
                      y: tooltipPosition.y + 50)
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
            return 0...100
        }
        let lower = floor(minValue - 10)
        let upper = ceil(maxValue + 10)
        return lower...upper
    }

    private var yAxisTicks: [Double] {
        let minY = yAxisRange.lowerBound
        let maxY = yAxisRange.upperBound
        let step: Double = 5
        return stride(from: (minY / step).rounded(.down) * step,
                      through: (maxY / step).rounded(.up) * step,
                      by: step).map { $0 }
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
