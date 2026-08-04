//
//  ThemeManager.swift
//  MeloNX
//
//  Created by Stossy11 on 8/6/2026.
//

import SwiftUI
import Combine

struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .defaultTheme
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet { persist() }
    }
    
    private let storageKey = "melonx_selected_theme_id"
    
    private init() {
        let savedId = UserDefaults.standard.string(forKey: "melonx_selected_theme_id") ?? "default"
        currentTheme = AppTheme.allBuiltIn.first { $0.id == savedId } ?? .defaultTheme
    }
    
    private func persist() {
        UserDefaults.standard.set(currentTheme.id, forKey: storageKey)
        applyUIKitAppearance()
    }
    
    func select(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
    
    func applyUIKitAppearance() {
        let accentUI = UIColor(currentTheme.accent.primary)
        
        UITabBar.appearance().tintColor = accentUI
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
        
        UINavigationBar.appearance().tintColor = accentUI
    }
}

struct ThemedViewModifier: ViewModifier {
    @ObservedObject var manager: ThemeManager = .shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, manager.currentTheme)
            .accentColor(manager.currentTheme.accent.primary)
            .preferredColorScheme(
                manager.currentTheme.backgroundStyle == .systemDefault ? nil : manager.currentTheme.isDark ? .dark : .light
            )
    }
}

extension View {
    func withAppTheme() -> some View {
        modifier(ThemedViewModifier())
    }
}


private struct ThemedBackgroundView: View {
    @ObservedObject private var manager: ThemeManager = .shared

    var body: some View {
        GeometryReader { geo in
            manager.currentTheme.backgroundStyle.makeBackground()
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func themedBackground() -> some View {
        self.background {
            ThemedBackgroundView()
        }
    }
}
