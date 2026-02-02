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
        } else if themeKey?.lowercased() == "neon" {
            currentTheme = .neon
        } else if themeKey?.lowercased() == "luxury" {
            currentTheme = .luxury
        }else if themeKey?.lowercased() == "arctic" {
            currentTheme = .arctic
        }else if themeKey?.lowercased() == "sand" {
            currentTheme = .sand
        }else if themeKey?.lowercased() == "forest" {
            currentTheme = .forest
        }else if themeKey?.lowercased() == "gas" {
            currentTheme = .gas
        }else if themeKey?.lowercased() == "lipstick" {
            currentTheme = .lipstick
        }else if themeKey?.lowercased() == "royal" {
            currentTheme = .royal
        }else{
            currentTheme = .standard
        }
    }
    
    /// Resolves and returns an AppTheme for a given theme key without updating the instance.
    /// - Parameter key: An optional string representing the theme identifier.
    /// - Returns: `.midnight` if the key is "midnight" (case insensitive), otherwise `.standard`.
    static func resolve(_ key: String?) -> AppTheme {
        if key?.lowercased() == "midnight" {
            return .midnight
        } else if key?.lowercased() == "neon" {
            return .neon
        } else if key?.lowercased() == "luxury" {
            return .luxury
        } else if key?.lowercased() == "arctic" {
            return .arctic
        } else if key?.lowercased() == "sand" {
            return .sand
        } else if key?.lowercased() == "forest" {
            return .forest
        } else if key?.lowercased() == "gas" {
            return .gas
        } else if key?.lowercased() == "lipstick" {
            return .lipstick
        } else if key?.lowercased() == "royal" {
            return .royal
        }else {
            return .standard
        }
    }
}
