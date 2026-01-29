import SwiftUI
import Combine

/// Manages the current application theme and publishes updates to subscribers.
@MainActor
class ThemeManager: ObservableObject {
    /// The currently selected app theme.
    @Published var currentTheme: AppTheme = .standard
    
    /// Updates the current theme based on the provided theme key.
    /// - Parameter themeKey: An optional string representing the theme identifier.
    /// If the key is "midnight" (case insensitive), the theme is set to `.midnight`.
    /// Otherwise, it defaults to `.standard`.
    func update(for themeKey: String?) {
        if themeKey?.lowercased() == "midnight" {
            currentTheme = .midnight
        } else {
            currentTheme = .standard
        }
    }
    
    /// Resolves and returns an AppTheme for a given theme key without updating the instance.
    /// - Parameter key: An optional string representing the theme identifier.
    /// - Returns: `.midnight` if the key is "midnight" (case insensitive), otherwise `.standard`.
    static func resolve(_ key: String?) -> AppTheme {
        if key?.lowercased() == "midnight" {
            return .midnight
        } else {
            return .standard
        }
    }
}
