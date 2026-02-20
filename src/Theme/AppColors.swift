//
//  AppColors.swift
//  SimplyFitness
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
    
    /// Neon theme
    static let neon = AppTheme(
        background: Color("NeonBackground"),
        surface: Color("NeonSurface"),
        navTop: Color("NeonNavTop"),
        navSide: Color("NeonNavSide"),
        textDefault: Color("NeonDefault"),
        textNav: Color("NeonNavText"),
        muted: Color("NeonMuted"),
        primary: Color("NeonPrimary"),
        secondary: Color("NeonSecondary"),
        borderDefault: Color("NeonBorder"),
        formDefault: Color("NeonFormElement"),
        success: Color("NeonSuccess"),
        warning: Color("NeonWarning"),
        error: Color("NeonError"),
        important: Color("NeonImportant"),
        pink: Color("NeonPink")
    )
    
    /// Luxury theme
    static let luxury = AppTheme(
        background: Color("LuxuryBackground"),
        surface: Color("LuxurySurface"),
        navTop: Color("LuxuryNavTop"),
        navSide: Color("LuxuryNavSide"),
        textDefault: Color("LuxuryDefault"),
        textNav: Color("LuxuryNavText"),
        muted: Color("LuxuryMuted"),
        primary: Color("LuxuryPrimary"),
        secondary: Color("LuxurySecondary"),
        borderDefault: Color("LuxuryBorder"),
        formDefault: Color("LuxuryFormElement"),
        success: Color("LuxurySuccess"),
        warning: Color("LuxuryWarning"),
        error: Color("LuxuryError"),
        important: Color("LuxuryImportant"),
        pink: Color("LuxuryPink")
    )
    
    /// Arctic theme
    static let arctic = AppTheme(
        background: Color("ArcticBackground"),
        surface: Color("ArcticSurface"),
        navTop: Color("ArcticNavTop"),
        navSide: Color("ArcticNavSide"),
        textDefault: Color("ArcticDefault"),
        textNav: Color("ArcticNavText"),
        muted: Color("ArcticMuted"),
        primary: Color("ArcticPrimary"),
        secondary: Color("ArcticSecondary"),
        borderDefault: Color("ArcticBorder"),
        formDefault: Color("ArcticFormElement"),
        success: Color("ArcticSuccess"),
        warning: Color("ArcticWarning"),
        error: Color("ArcticError"),
        important: Color("ArcticImportant"),
        pink: Color("ArcticPink")
    )
    
    /// Forest theme
    static let forest = AppTheme(
        background: Color("ForestBackground"),
        surface: Color("ForestSurface"),
        navTop: Color("ForestNavTop"),
        navSide: Color("ForestNavSide"),
        textDefault: Color("ForestDefault"),
        textNav: Color("ForestNavText"),
        muted: Color("ForestMuted"),
        primary: Color("ForestPrimary"),
        secondary: Color("ForestSecondary"),
        borderDefault: Color("ForestBorder"),
        formDefault: Color("ForestFormElement"),
        success: Color("ForestSuccess"),
        warning: Color("ForestWarning"),
        error: Color("ForestError"),
        important: Color("ForestImportant"),
        pink: Color("ForestPink")
    )
    
    /// Sand theme
    static let sand = AppTheme(
        background: Color("SandBackground"),
        surface: Color("SandSurface"),
        navTop: Color("SandNavTop"),
        navSide: Color("SandNavSide"),
        textDefault: Color("SandDefault"),
        textNav: Color("SandNavText"),
        muted: Color("SandMuted"),
        primary: Color("SandPrimary"),
        secondary: Color("SandSecondary"),
        borderDefault: Color("SandBorder"),
        formDefault: Color("SandFormElement"),
        success: Color("SandSuccess"),
        warning: Color("SandWarning"),
        error: Color("SandError"),
        important: Color("SandImportant"),
        pink: Color("SandPink")
    )
    
    /// Gas theme
    static let gas = AppTheme(
        background: Color("GasBackground"),
        surface: Color("GasSurface"),
        navTop: Color("GasNavTop"),
        navSide: Color("GasNavSide"),
        textDefault: Color("GasDefault"),
        textNav: Color("GasNavText"),
        muted: Color("GasMuted"),
        primary: Color("GasPrimary"),
        secondary: Color("GasSecondary"),
        borderDefault: Color("GasBorder"),
        formDefault: Color("GasFormElement"),
        success: Color("GasSuccess"),
        warning: Color("GasWarning"),
        error: Color("GasError"),
        important: Color("GasImportant"),
        pink: Color("GasPink")
    )
    
    /// Lipstick theme
    static let lipstick = AppTheme(
        background: Color("LipstickBackground"),
        surface: Color("LipstickSurface"),
        navTop: Color("LipstickNavTop"),
        navSide: Color("LipstickNavSide"),
        textDefault: Color("LipstickDefault"),
        textNav: Color("LipstickNavText"),
        muted: Color("LipstickMuted"),
        primary: Color("LipstickPrimary"),
        secondary: Color("LipstickSecondary"),
        borderDefault: Color("LipstickBorder"),
        formDefault: Color("LipstickFormElement"),
        success: Color("LipstickSuccess"),
        warning: Color("LipstickWarning"),
        error: Color("LipstickError"),
        important: Color("LipstickImportant"),
        pink: Color("LipstickPink")
    )
    
    /// Royal theme
    static let royal = AppTheme(
        background: Color("RoyalBackground"),
        surface: Color("RoyalSurface"),
        navTop: Color("RoyalNavTop"),
        navSide: Color("RoyalNavSide"),
        textDefault: Color("RoyalDefault"),
        textNav: Color("RoyalNavText"),
        muted: Color("RoyalMuted"),
        primary: Color("RoyalPrimary"),
        secondary: Color("RoyalSecondary"),
        borderDefault: Color("RoyalBorder"),
        formDefault: Color("RoyalFormElement"),
        success: Color("RoyalSuccess"),
        warning: Color("RoyalWarning"),
        error: Color("RoyalError"),
        important: Color("RoyalImportant"),
        pink: Color("RoyalPink")
    )
}
