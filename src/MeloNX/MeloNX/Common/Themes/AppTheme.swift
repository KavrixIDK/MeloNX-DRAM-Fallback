//
//  AppTheme.swift
//  MeloNX
//
//  Created by Stossy11 on 8/6/2026.
//

import SwiftUI
import Foundation

struct ThemeAccent: Equatable {
    let primary: Color
    let secondary: Color
    
    static let blue   = ThemeAccent(primary: Color(hex: "#3A7BFF"), secondary: Color(hex: "#6FA0FF"))
    static let red    = ThemeAccent(primary: Color(hex: "#FF3B3B"), secondary: Color(hex: "#FF7070"))
    static let purple = ThemeAccent(primary: Color(hex: "#9B5EFF"), secondary: Color(hex: "#BF92FF"))
    static let orange = ThemeAccent(primary: Color(hex: "#FF8C00"), secondary: Color(hex: "#FFB347"))
    static let teal   = ThemeAccent(primary: Color(hex: "#00C4B4"), secondary: Color(hex: "#50D9CC"))
    static let green  = ThemeAccent(primary: Color(hex: "#2DBD6E"), secondary: Color(hex: "#5CDA95"))
    static let pink   = ThemeAccent(primary: Color(hex: "#FF2D78"), secondary: Color(hex: "#FF6FA8"))
    static let gold   = ThemeAccent(primary: Color(hex: "#D4A017"), secondary: Color(hex: "#F0C84A"))
}

enum BackgroundStyle: String, Codable, CaseIterable {
    case systemDefault   = "Default"
    case solidDark       = "Dark"
    case solidLight      = "Light"
    case oled            = "OLED Black"
    case gradientAurora  = "Aurora"
    case gradientForest  = "Forest"
    case gradientSunset  = "Sunset"
    case gradientOcean   = "Ocean"
    case gradientGold    = "Gold"
    case gradientCrimson = "Crimson"
    case gradientQueer   = "Queer"
    case lily            = "In Remembrance of Lily"
    case chapter5        = "The Field of Pink and Gold"

    var displayName: String { rawValue }

    @ViewBuilder
    func makeBackground() -> some View {
        switch self {
        case .systemDefault:
            Color(.systemGroupedBackground)

        case .solidDark:
            Color(hex: "#0F0F14")

        case .solidLight:
            Color(hex: "#F2F2F7")

        case .oled:
            Color.black

        case .gradientAurora:
            LinearGradient(
                colors: [Color(hex: "#050D1A"), Color(hex: "#0A2A2A"), Color(hex: "#0D1A12")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .gradientSunset:
            LinearGradient(
                colors: [Color(hex: "#1A080A"), Color(hex: "#2A1200"), Color(hex: "#1A0A0A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .gradientOcean:
            LinearGradient(
                colors: [Color(hex: "#050A1A"), Color(hex: "#0A1428"), Color(hex: "#050D1E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .gradientForest:
            LinearGradient(
                colors: [Color(hex: "#051A08"), Color(hex: "#0A2E10"), Color(hex: "#061A0A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
        case .gradientCrimson:
            LinearGradient(
                colors: [Color(hex: "#1C0605"), Color(hex: "#300B09"), Color(hex: "#210402")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .gradientGold:
            LinearGradient(
                colors: [
                    Color(hex: "#2A1A00"),
                    Color(hex: "#3D2600"),
                    Color(hex: "#1F1200")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .chapter5:
            LinearGradient(
                colors: [
                    Color(hex: "#76375c"),
                    Color(hex: "#76375c"),
                    Color(hex: "#85412a"),
                    Color(hex: "#695d2f"),
                    Color(hex: "#85412a"),
                    Color(hex: "#76375c"),
                    Color(hex: "#76375c")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
        case .gradientQueer:
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#06050F"), location: 0.00),
                    .init(color: Color(hex: "#0E0910"), location: 0.07),
                    .init(color: Color(hex: "#110B0D"), location: 0.14),
                    .init(color: Color(hex: "#160A0C"), location: 0.21),
                    .init(color: Color(hex: "#1A0810"), location: 0.28),
                    .init(color: Color(hex: "#1A0C0D"), location: 0.35),
                    .init(color: Color(hex: "#1A100A"), location: 0.42),
                    .init(color: Color(hex: "#181408"), location: 0.48),
                    .init(color: Color(hex: "#161608"), location: 0.50),
                    .init(color: Color(hex: "#161608"), location: 0.52),
                    .init(color: Color(hex: "#0A160A"), location: 0.59),
                    .init(color: Color(hex: "#06120E"), location: 0.66),
                    .init(color: Color(hex: "#080F18"), location: 0.73),
                    .init(color: Color(hex: "#090C1E"), location: 0.80),
                    .init(color: Color(hex: "#0C091C"), location: 0.87),
                    .init(color: Color(hex: "#110818"), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lily:
            LinearGradient(
                colors: [Color(hex: "#0D0A1F"), Color(hex: "#1A0E3D"), Color(hex: "#120D35")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct AppTheme: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let accentColorHex: String
    let accentSecondaryHex: String
    let backgroundStyle: BackgroundStyle
    let isDark: Bool

    var accent: ThemeAccent {
        ThemeAccent(
            primary: Color(hex: accentColorHex),
            secondary: Color(hex: accentSecondaryHex)
        )
    }

    init(
        id: String,
        name: String,
        accentColorHex: String,
        accentSecondaryHex: String,
        backgroundStyle: BackgroundStyle,
        isDark: Bool
    ) {
        self.id = id
        self.name = name
        self.accentColorHex = accentColorHex
        self.accentSecondaryHex = accentSecondaryHex
        self.backgroundStyle = backgroundStyle
        self.isDark = isDark
    }

    init(
        id: String,
        name: String,
        accent: ThemeAccent,
        backgroundStyle: BackgroundStyle,
        isDark: Bool
    ) {
        guard
            let primaryHex = accent.primary.toHex(),
            let secondaryHex = accent.secondary.toHex()
        else {
            assertionFailure(
                "ThemeAccent colours must be hex-constructible. " +
                "Do not use system/dynamic colours (e.g. .accentColor) here."
            )
            self.init(
                id: id, name: name,
                accentColorHex: "#000000", accentSecondaryHex: "#000000",
                backgroundStyle: backgroundStyle, isDark: isDark
            )
            return
        }
        self.init(
            id: id, name: name,
            accentColorHex: primaryHex, accentSecondaryHex: secondaryHex,
            backgroundStyle: backgroundStyle, isDark: isDark
        )
    }
}

extension AppTheme {

    static let allBuiltIn: [AppTheme] = [
        .defaultTheme,
        .aurora,
        .scarlet,
        .sunset,
        .ocean,
        .oled,
        .forest,
        .rose,
        .gold,
        .chapter5,
        .lily,
        .queer
    ]

    static let defaultTheme = AppTheme(
        id: "default",
        name: "Default",
        accentColorHex: "#3A7BFF",
        accentSecondaryHex: "#6FA0FF",
        backgroundStyle: .systemDefault,
        isDark: false
    )

    static let aurora = AppTheme(
        id: "aurora",
        name: "Aurora",
        accentColorHex: "#00C4B4",
        accentSecondaryHex: "#50D9CC",
        backgroundStyle: .gradientAurora,
        isDark: true
    )

    static let scarlet = AppTheme(
        id: "scarlet",
        name: "Scarlet",
        accentColorHex: "#FF3B3B",
        accentSecondaryHex: "#FF7070",
        backgroundStyle: .gradientCrimson,
        isDark: true
    )

    static let sunset = AppTheme(
        id: "sunset",
        name: "Sunset",
        accentColorHex: "#FF8C00",
        accentSecondaryHex: "#FFB347",
        backgroundStyle: .gradientSunset,
        isDark: true
    )

    static let ocean = AppTheme(
        id: "ocean",
        name: "Ocean",
        accentColorHex: "#3A7BFF",
        accentSecondaryHex: "#6FA0FF",
        backgroundStyle: .gradientOcean,
        isDark: true
    )

    static let oled = AppTheme(
        id: "oled",
        name: "OLED Black",
        accentColorHex: "#FFFFFF",
        accentSecondaryHex: "#AAAAAA",
        backgroundStyle: .oled,
        isDark: true
    )

    static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        accentColorHex: "#2DBD6E",
        accentSecondaryHex: "#5CDA95",
        backgroundStyle: .gradientForest,
        isDark: true
    )

    static let rose = AppTheme(
        id: "rose",
        name: "Rose",
        accentColorHex: "#FF2D78",
        accentSecondaryHex: "#FF6FA8",
        backgroundStyle: .solidDark,
        isDark: true
    )

    static let gold = AppTheme(
        id: "gold",
        name: "Gold",
        accentColorHex: "#D4A017",
        accentSecondaryHex: "#F0C84A",
        backgroundStyle: .gradientGold,
        isDark: true
    )
    
    static let queer = AppTheme(
        id: "queer",
        name: "MeloPride",
        accentColorHex: "#a6717b",
        accentSecondaryHex: "#2D6C85",
        backgroundStyle: .gradientQueer,
        isDark: true
    )

    static let lily = AppTheme(
        id: "lily",
        name: "Always Remembered",
        accentColorHex: "#9B5EFF",
        accentSecondaryHex: "#BF92FF",
        backgroundStyle: .lily,
        isDark: true
    )
    
    static let chapter5 = AppTheme(
        id: "chapter5",
        name: "Jarona!",
        accentColorHex: "#f47272",
        accentSecondaryHex: "#fde463",
        backgroundStyle: .chapter5,
        isDark: true
    )
}
