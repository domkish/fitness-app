//
//  SetChartPoint.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/2/26.
//
import Foundation

struct SetChartPoint: Identifiable {
    let id = UUID()
    let setIndex: Int
    let value: Double
    let reps: Int
    let unit: String
    let isPrevious: Bool
}

