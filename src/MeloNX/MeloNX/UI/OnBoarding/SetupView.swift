//
//  SetupView.swift
//  MeloNX
//
//  Created by Stossy11 on 6/7/2026.
//

import SwiftUI

enum SetupPage: String, Identifiable, CaseIterable {
    case welcome
    case keys
    case firmware

    var id: String { rawValue }

    static var first: Self = .welcome
}

struct SetupView: View {
    var finishSetup: () -> Void
    private let pages = SetupPage.allCases
    
    @State var currentPage: SetupPage = .first
    
    var body: some View {
        switch currentPage {
        case .welcome: WelcomeView(goForward: goForward).transition(.backslide)
        case .keys: KeysView(goForward: goForward).transition(.backslide)
        case .firmware: FirmwareView(goForward: goForward).transition(.backslide)
        }
    }
    
    func goForward() {
        withAnimation {
            switch currentPage {
            case .welcome:
                currentPage = .keys
            case .keys:
                currentPage = .firmware
            case .firmware:
                finishSetup()
            }
        }
    }
}

struct ContinueButton: View {
    var text: LocalizedStringKey
    var action: () -> Void
    
    var success: Bool = false
    @Binding var enabled: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var shadowColor: Color {
        guard !success else { return .green.opacity(colorScheme == .dark ? 0.3 : 0.1) }
        return (enabled ? .accentColor : Color(.darkGray).opacity(colorScheme == .dark ? 0.3 : 0.1))
    }
    
    func doAction() {
        if enabled { action() }
    }
    
    var borderColor: Color {
        guard !success else { return .green }
        return enabled ? Color.accentColor : Color(.systemGray4)
    }
    
    var textColour: Color {
        guard !success else { return .green }
        return enabled ? Color.white : Color(.systemGray4)
    }
    
    var backgroundColour: Color {
        guard !success else { return .green.opacity(0.15)}
        return enabled ? .accentColor.opacity(0.15) : .clear
    }
    
    var body: some View {
        Button(action: doAction) {
            Text(success ? "✓" : text)
                .padding()
                .padding(.horizontal, 24)
                .foregroundStyle(textColour)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColour)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
        }
        .disabled(!enabled)
    }
}

extension Image {
    init(appIconBundle: Bundle) {
        self.init(uiImage: UIImage(named: Self.appIcon(in: appIconBundle)) ?? UIImage())
    }
    
    
    static func appIcon(in bundle: Bundle = .main) -> String {
        guard let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              
              let iconFileName = iconFiles.last else {

            // print("Could not find icons in bundle")
            return ""
        }

        return iconFileName
    }
}

extension Bundle {
    var versionNumber: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

extension AnyTransition {
    static var backslide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }
}
