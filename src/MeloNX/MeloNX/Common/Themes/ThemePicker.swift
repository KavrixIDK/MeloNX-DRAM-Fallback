//
//  ThemePicker.swift
//  MeloNX
//
//  Created by Stossy11 on 8/6/2026.
//

import SwiftUI

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    currentThemeHero
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Themes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AppTheme.allBuiltIn) { theme in
                                ThemeCard(theme: theme, isSelected: themeManager.currentTheme.id == theme.id) {
                                    themeManager.select(theme)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var currentThemeHero: some View {
        HStack(spacing: 16) {
            ThemeMiniPreview(theme: themeManager.currentTheme)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.currentTheme.name)
                    .font(.title2.bold())
                Text(themeManager.currentTheme.backgroundStyle.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeManager.currentTheme.accent.primary)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(themeManager.currentTheme.accent.secondary)
                        .frame(width: 16, height: 16)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(themeManager.currentTheme.accent.primary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.currentTheme.accent.primary.opacity(0.4), lineWidth: 1.5)
        )
    }
}

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                ThemeMiniPreview(theme: theme)
                    .frame(height: 90)
                    .clipped()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(theme.backgroundStyle.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? theme.accent.primary : Color(.systemGray4), lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(color: isSelected ? theme.accent.primary.opacity(0.3) : .clear, radius: 8, y: 3)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct ThemeMiniPreview: View {
    let theme: AppTheme
    
    var body: some View {
        ZStack {
            theme.backgroundStyle.makeBackground()
            
            VStack(spacing: 4) {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.5))
                        .frame(width: 30, height: 4)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accent.secondary.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.12))
                            .frame(width: 22, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
                            )
                    }
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { i in
                        Spacer()
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i == 0 ? theme.accent.primary : .white.opacity(0.3))
                                .frame(width: 14, height: 14)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i == 0 ? theme.accent.primary.opacity(0.7) : .white.opacity(0.2))
                                .frame(width: 20, height: 2)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                .background(.black.opacity(0.25))
            }
        }
    }
}
