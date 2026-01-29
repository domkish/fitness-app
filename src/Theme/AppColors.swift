//
//  AppColors.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct AppColors {
    // Background layers
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let navTop = Color("NavTop")
    static let navSide = Color("NavSide")
    
    // Text
    static let textDefault = Color("Default")
    static let textNav = Color("NavText")
    static let muted = Color("Muted")
    
    // Brand
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    
    // UI/UX
    static let borderDefault = Color("Border")
    static let formDefault = Color("FormElement")
    
    // Status colors
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")
    static let important = Color("Important")
    static let pink = Color("Pink")
}

// MARK: - Theme Definition
struct AppTheme {
    let background: Color
    let surface: Color
    let navTop: Color
    let navSide: Color

    let textDefault: Color
    let textNav: Color
    let muted: Color

    let primary: Color
    let secondary: Color

    let borderDefault: Color
    let formDefault: Color

    let success: Color
    let warning: Color
    let error: Color
    let important: Color
    let pink: Color
}

// MARK: - Theme Presets
extension AppTheme {

    /// Default app theme (uses AppColors)
    static let standard = AppTheme(
        background: AppColors.background,
        surface: AppColors.surface,
        navTop: AppColors.navTop,
        navSide: AppColors.navSide,
        textDefault: AppColors.textDefault,
        textNav: AppColors.textNav,
        muted: AppColors.muted,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        borderDefault: AppColors.borderDefault,
        formDefault: AppColors.formDefault,
        success: AppColors.success,
        warning: AppColors.warning,
        error: AppColors.error,
        important: AppColors.important,
        pink: AppColors.pink
    )

    /// Midnight theme
    static let midnight = AppTheme(
        background: Color("MidnightBackground"),
        surface: Color("MidnightSurface"),
        navTop: Color("MidnightNavTop"),
        navSide: Color("MidnightNavSide"),
        textDefault: Color("MidnightDefault"),
        textNav: Color("MidnightNavText"),
        muted: Color("MidnightMuted"),
        primary: Color("MidnightPrimary"),
        secondary: Color("MidnightSecondary"),
        borderDefault: Color("MidnightBorder"),
        formDefault: Color("MidnightFormElement"),
        success: Color("MidnightSuccess"),
        warning: Color("MidnightWarning"),
        error: Color("MidnightError"),
        important: Color("MidnightImportant"),
        pink: Color("MidnightPink")
    )
}
