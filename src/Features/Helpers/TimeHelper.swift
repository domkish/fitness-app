//
//  TimeHelper.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/3/26.
//
import SwiftUI
import Foundation

public func formattedDurationLong(_ seconds: Int) -> String {
    let hrs = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    var parts: [String] = []
    if hrs > 0 { parts.append("\(hrs) " + (hrs == 1 ? "Hour" : "Hours")) }
    if mins > 0 { parts.append("\(mins) " + (mins == 1 ? "Minute" : "Minutes")) }
    if secs > 0 || parts.isEmpty { parts.append("\(secs) " + (secs == 1 ? "Second" : "Seconds")) }
    return parts.joined(separator: ", ")
}

public func formattedTime(_ seconds: Int) -> String {
    let hrs = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d:%02d", hrs, mins, secs)
}
