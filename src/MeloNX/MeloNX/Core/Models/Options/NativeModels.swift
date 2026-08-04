//
//  NativeModels.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import Foundation
import SwiftUI

enum VSyncMode: Int32, Codable, CaseIterable, Identifiable {
    case switchMode = 0
    case unbounded = 1
    case custom = 2

    var id: Int32 { rawValue }

    var displayName: String {
        switch self {
        case .switchMode: return String(localized: "Switch")
        case .unbounded: return String(localized: "Unbounded")
        case .custom: return String(localized: "Custom")
        }
    }
}

extension ControllerType: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [ControllerType] = [
        .proController, .handheld, .joyconPair, .joyconLeft, .joyconRight, .pokeball,
    ]
    
    public static var none: ControllerType { .init(rawValue: 0) }
    
    var displayName: String {
        switch self {
        case .proController: return String(localized: "Pro Controller")
        case .handheld: return String(localized: "Handheld")
        case .joyconPair: return String(localized: "Joy-Con Pair")
        case .joyconLeft: return String(localized: "Joy-Con Left")
        case .joyconRight: return String(localized: "Joy-Con Right")
        case .pokeball: return String(localized: "Poké Ball")
        default: return String(localized: "Unknown")
        }
    }
}

extension AspectRatio: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [AspectRatio] = [
        .fixed16x9, .fixed4x3, .fixed21x9, .fixed32x9, .fixed16x10, .stretched,
    ]
    
    var displayName: String {
        switch self {
        case .fixed16x9: return String(localized: "16:9")
        case .fixed4x3: return String(localized: "4:3") // :3
        case .fixed21x9: return String(localized: "21:9")
        case .fixed32x9: return String(localized: "32:9")
        case .fixed16x10: return String(localized: "16:10")
        case .stretched: return String(localized: "Stretched")
        @unknown default: return String(localized: "Unknown")
        }
    }
}

extension SystemLanguage: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [SystemLanguage] = [
        .japanese, .americanEnglish, .french, .german, .italian, .spanish,
        .chinese, .korean, .dutch, .portuguese, .russian, .taiwanese,
        .britishEnglish, .canadianFrench, .latinAmericanSpanish,
        .simplifiedChinese, .traditionalChinese, .brazilianPortuguese, .polish, .thai,
    ]
    
    var displayName: String {
        switch self {
        case .japanese: return String(localized: "Japanese")
        case .americanEnglish: return String(localized: "American English")
        case .french: return String(localized: "French")
        case .german: return String(localized: "German")
        case .italian: return String(localized: "Italian")
        case .spanish: return String(localized: "Spanish")
        case .chinese: return String(localized: "Chinese")
        case .korean: return String(localized: "Korean")
        case .dutch: return String(localized: "Dutch")
        case .portuguese: return String(localized: "Portuguese")
        case .russian: return String(localized: "Russian")
        case .taiwanese: return String(localized: "Taiwanese")
        case .britishEnglish: return String(localized: "British English")
        case .canadianFrench: return String(localized: "Canadian French")
        case .latinAmericanSpanish: return String(localized: "Latin American Spanish")
        case .simplifiedChinese: return String(localized: "Simplified Chinese")
        case .traditionalChinese: return String(localized: "Traditional Chinese")
        case .brazilianPortuguese: return String(localized: "Brazilian Portuguese")
        case .polish: return String(localized: "Polish")
        case .thai: return String(localized: "Thai")
        @unknown default: return String(localized: "Unknown")
        }
    }
}

extension HideCursorMode: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [HideCursorMode] = [
        .never, .onIdle, .always,
    ]
    
    var displayName: String {
        switch self {
        case .never: return String(localized: "Never")
        case .onIdle: return String(localized: "On Idle")
        case .always: return String(localized: "Always")
        default: return String(localized: "Unknown")
        }
    }
}

extension NativeRegionCode: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [NativeRegionCode] = [
        .japan, .USA, .europe, .australia, .china, .korea, .taiwan,
    ]
    
    var displayName: String {
        switch self {
        case .japan: return String(localized: "Japan")
        case .USA: return String(localized: "USA")
        case .europe: return String(localized: "Europe")
        case .australia: return String(localized: "Australia")
        case .china: return String(localized: "China")
        case .korea: return String(localized: "Korea")
        case .taiwan: return String(localized: "Taiwan")
        default: return String(localized: "Unknown")
        }
    }
    
    init?(swiftRegionCode: String?) {
        switch swiftRegionCode?.uppercased() {
        case "JP":           self = .japan
        case "US":           self = .USA
        case "GB", "EU",
            "DE", "FR",
            "IT", "ES",
            "NL", "PT",
            "BE", "AT",
            "SE", "NO",
            "DK", "FI",
            "CH", "IE",
            "PL", "CZ",
            "HU", "RO",
            "GR", "SK",
            "BG", "HR",
            "SI", "EE",
            "LV", "LT",
            "LU", "MT",
            "CY":           self = .europe
        case "AU", "NZ":     self = .australia
        case "CN":           self = .china
        case "KR":           self = .korea
        case "TW":           self = .taiwan
        default:             return nil
        }
    }
}

extension MemoryManagerMode: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }

    public static var allCases: [MemoryManagerMode] = [
        .softwarePageTable, .hostMapped, .hostMappedUnsafe,
    ]

    var displayName: String {
        switch self {
        case .softwarePageTable: return String(localized: "Software Page Table")
        case .hostMapped: return String(localized: "Host Mapped")
        case .hostMappedUnsafe: return String(localized: "Host Mapped Unsafe")
        default: return String(localized: "Unknown")
        }
    }
}

extension GraphicsDebugLevel: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }

    public static var allCases: [GraphicsDebugLevel] = [
        .none, .error, .slowdowns, .all,
    ]

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .error: return String(localized: "Error")
        case .slowdowns: return String(localized: "Slowdowns")
        case .all: return String(localized: "All")
        default: return String(localized: "Unknown")
        }
    }
}

extension BackendThreading: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [BackendThreading] = [
        .auto, .off, .on,
    ]
    
    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .off: return String(localized: "Off")
        case .on: return String(localized: "On")
        default: return String(localized: "Unknown")
        }
    }
}

extension AntiAliasing: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }

    public static var allCases: [AntiAliasing] = [
        .none, .fxaa, .smaaLow, .smaaMedium, .smaaHigh, .smaaUltra,
    ]

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .fxaa: return String(localized: "FXAA")
        case .smaaLow: return String(localized: "SMAA Low")
        case .smaaMedium: return String(localized: "SMAA Medium")
        case .smaaHigh: return String(localized: "SMAA High")
        case .smaaUltra: return String(localized: "SMAA Ultra")
        default: return String(localized: "Unknown")
        }
    }
}

extension ScalingFilter: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [ScalingFilter] = [
        .bilinear, .nearest, .fsr, .area
    ]
    
    var displayName: String {
        switch self {
        case .bilinear: return String(localized: "Bilinear")
        case .nearest: return String(localized: "Nearest")
        case .fsr: return String(localized: "FSR")
        case .area: return String(localized: "Area")
        default: return String(localized: "Unknown")
        }
    }
}

extension GraphicsBackend: CaseIterable, Identifiable {
    public var id: Int { Int(self.rawValue) }
    
    public static var allCases: [GraphicsBackend] = [
        .vulkan, .openGl,
    ]
    
    var displayName: String {
        switch self {
        case .vulkan: return String(localized: "Vulkan")
        case .openGl: return String(localized: "OpenGL")
        default: return String(localized: "Unknown")
        }
    }
}

extension LeftJoyconCommonConfigNative: Codable {
    enum CodingKeys: String, CodingKey {
        case DpadUp, DpadDown, DpadLeft, DpadRight
        case ButtonMinus, ButtonL, ButtonZl, ButtonSl, ButtonSr
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            DpadUp:      try container.decode(Key.self, forKey: .DpadUp),
            DpadDown:    try container.decode(Key.self, forKey: .DpadDown),
            DpadLeft:    try container.decode(Key.self, forKey: .DpadLeft),
            DpadRight:   try container.decode(Key.self, forKey: .DpadRight),
            ButtonMinus: try container.decode(Key.self, forKey: .ButtonMinus),
            ButtonL:     try container.decode(Key.self, forKey: .ButtonL),
            ButtonZl:    try container.decode(Key.self, forKey: .ButtonZl),
            ButtonSl:    try container.decode(Key.self, forKey: .ButtonSl),
            ButtonSr:    try container.decode(Key.self, forKey: .ButtonSr)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(DpadUp,      forKey: .DpadUp)
        try container.encode(DpadDown,    forKey: .DpadDown)
        try container.encode(DpadLeft,    forKey: .DpadLeft)
        try container.encode(DpadRight,   forKey: .DpadRight)
        try container.encode(ButtonMinus, forKey: .ButtonMinus)
        try container.encode(ButtonL,     forKey: .ButtonL)
        try container.encode(ButtonZl,    forKey: .ButtonZl)
        try container.encode(ButtonSl,    forKey: .ButtonSl)
        try container.encode(ButtonSr,    forKey: .ButtonSr)
    }
}


extension RightJoyconCommonConfigNative: Codable {
    enum CodingKeys: String, CodingKey {
        case ButtonA, ButtonB, ButtonX, ButtonY
        case ButtonPlus, ButtonR, ButtonZr, ButtonSl, ButtonSr
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ButtonA:     try container.decode(Key.self, forKey: .ButtonA),
            ButtonB:     try container.decode(Key.self, forKey: .ButtonB),
            ButtonX:     try container.decode(Key.self, forKey: .ButtonX),
            ButtonY:     try container.decode(Key.self, forKey: .ButtonY),
            ButtonPlus:  try container.decode(Key.self, forKey: .ButtonPlus),
            ButtonR:     try container.decode(Key.self, forKey: .ButtonR),
            ButtonZr:    try container.decode(Key.self, forKey: .ButtonZr),
            ButtonSl:    try container.decode(Key.self, forKey: .ButtonSl),
            ButtonSr:    try container.decode(Key.self, forKey: .ButtonSr)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ButtonA,    forKey: .ButtonA)
        try container.encode(ButtonB,    forKey: .ButtonB)
        try container.encode(ButtonX,    forKey: .ButtonX)
        try container.encode(ButtonY,    forKey: .ButtonY)
        try container.encode(ButtonPlus, forKey: .ButtonPlus)
        try container.encode(ButtonR,    forKey: .ButtonR)
        try container.encode(ButtonZr,   forKey: .ButtonZr)
        try container.encode(ButtonSl,   forKey: .ButtonSl)
        try container.encode(ButtonSr,   forKey: .ButtonSr)
    }
}

extension JoyconConfigKeyboardStickNative: Codable {
    enum CodingKeys: String, CodingKey {
        case StickUp, StickDown, StickLeft, StickRight, StickButton
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            StickUp:     try container.decode(Key.self, forKey: .StickUp),
            StickDown:   try container.decode(Key.self, forKey: .StickDown),
            StickLeft:   try container.decode(Key.self, forKey: .StickLeft),
            StickRight:  try container.decode(Key.self, forKey: .StickRight),
            StickButton: try container.decode(Key.self, forKey: .StickButton)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(StickUp,     forKey: .StickUp)
        try container.encode(StickDown,   forKey: .StickDown)
        try container.encode(StickLeft,   forKey: .StickLeft)
        try container.encode(StickRight,  forKey: .StickRight)
        try container.encode(StickButton, forKey: .StickButton)
    }
}

extension KeyboardConfigNative: Codable {
    enum CodingKeys: String, CodingKey {
        case LeftJoycon, LeftJoyconStick, RightJoycon, RightJoyconStick
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            LeftJoycon:        try container.decode(LeftJoyconCommonConfigNative.self, forKey: .LeftJoycon),
            LeftJoyconStick:   try container.decode(JoyconConfigKeyboardStickNative.self, forKey: .LeftJoyconStick),
            RightJoycon:       try container.decode(RightJoyconCommonConfigNative.self, forKey: .RightJoycon),
            RightJoyconStick:  try container.decode(JoyconConfigKeyboardStickNative.self, forKey: .RightJoyconStick),
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(LeftJoycon,       forKey: .LeftJoycon)
        try container.encode(LeftJoyconStick,  forKey: .LeftJoyconStick)
        try container.encode(RightJoycon,      forKey: .RightJoycon)
        try container.encode(RightJoyconStick, forKey: .RightJoyconStick)
    }
}

extension Key: CaseIterable, Identifiable, Codable {
    public var id: UInt32 { self.rawValue }
    
    public static var allCases: [Key] = [
        // Key_Unknown,
        Key_ShiftLeft,
        Key_ShiftRight,
        Key_ControlLeft,
        Key_ControlRight,
        Key_AltLeft,
        Key_AltRight,
        Key_WinLeft,
        Key_WinRight,
        Key_Menu,
        
        Key_F1,
        Key_F2,
        Key_F3,
        Key_F4,
        Key_F5,
        Key_F6,
        Key_F7,
        Key_F8,
        Key_F9,
        Key_F10,
        Key_F11,
        Key_F12,
        Key_F13,
        Key_F14,
        Key_F15,
        Key_F16,
        Key_F17,
        Key_F18,
        Key_F19,
        Key_F20,
        Key_F21,
        Key_F22,
        Key_F23,
        Key_F24,
        Key_F25,
        Key_F26,
        Key_F27,
        Key_F28,
        Key_F29,
        Key_F30,
        Key_F31,
        Key_F32,
        Key_F33,
        Key_F34,
        Key_F35,
        
        Key_Up,
        Key_Down,
        Key_Left,
        Key_Right,
        
        Key_Enter,
        Key_Escape,
        Key_Space,
        Key_Tab,
        Key_BackSpace,
        
        Key_Insert,
        Key_Delete,
        Key_PageUp,
        Key_PageDown,
        Key_Home,
        Key_End,
        
        Key_CapsLock,
        Key_ScrollLock,
        Key_PrintScreen,
        Key_Pause,
        Key_NumLock,
        Key_Clear,
        
        Key_Keypad0,
        Key_Keypad1,
        Key_Keypad2,
        Key_Keypad3,
        Key_Keypad4,
        Key_Keypad5,
        Key_Keypad6,
        Key_Keypad7,
        Key_Keypad8,
        Key_Keypad9,
        
        Key_KeypadDivide,
        Key_KeypadMultiply,
        Key_KeypadSubtract,
        Key_KeypadAdd,
        Key_KeypadDecimal,
        Key_KeypadEnter,
        
        Key_A,
        Key_B,
        Key_C,
        Key_D,
        Key_E,
        Key_F,
        Key_G,
        Key_H,
        Key_I,
        Key_J,
        Key_K,
        Key_L,
        Key_M,
        Key_N,
        Key_O,
        Key_P,
        Key_Q,
        Key_R,
        Key_S,
        Key_T,
        Key_U,
        Key_V,
        Key_W,
        Key_X,
        Key_Y,
        Key_Z,
        
        Key_Number0,
        Key_Number1,
        Key_Number2,
        Key_Number3,
        Key_Number4,
        Key_Number5,
        Key_Number6,
        Key_Number7,
        Key_Number8,
        Key_Number9,
        
        Key_Tilde,
        Key_Grave,
        Key_Minus,
        Key_Plus,
        Key_BracketLeft,
        Key_BracketRight,
        Key_Semicolon,
        Key_Quote,
        Key_Comma,
        Key_Period,
        Key_Slash,
        Key_BackSlash,
        
        Key_Unbound,
        
        // Key_Count
    ]
    
    var displayName: String {
        switch self {
        case Key_ShiftLeft:
            return String(localized: "Left Shift")
        case Key_ShiftRight:
            return String(localized: "Right Shift")
        case Key_ControlLeft:
            return String(localized: "Left Control")
        case Key_ControlRight:
            return String(localized: "Right Control")
        case Key_AltLeft:
            return String(localized: "Left Alt")
        case Key_AltRight:
            return String(localized: "Right Alt")
        case Key_WinLeft:
            return String(localized: "Left Windows")
        case Key_WinRight:
            return String(localized: "Right Windows")
        case Key_Menu:
            return String(localized: "Menu")
            
        case Key_F1: return String(localized: "F1")
        case Key_F2: return String(localized: "F2")
        case Key_F3: return String(localized: "F3")
        case Key_F4: return String(localized: "F4")
        case Key_F5: return String(localized: "F5")
        case Key_F6: return String(localized: "F6")
        case Key_F7: return String(localized: "F7")
        case Key_F8: return String(localized: "F8")
        case Key_F9: return String(localized: "F9")
        case Key_F10: return String(localized: "F10")
        case Key_F11: return String(localized: "F11")
        case Key_F12: return String(localized: "F12")
        case Key_F13: return String(localized: "F13")
        case Key_F14: return String(localized: "F14")
        case Key_F15: return String(localized: "F15")
        case Key_F16: return String(localized: "F16")
        case Key_F17: return String(localized: "F17")
        case Key_F18: return String(localized: "F18")
        case Key_F19: return String(localized: "F19")
        case Key_F20: return String(localized: "F20")
        case Key_F21: return String(localized: "F21")
        case Key_F22: return String(localized: "F22")
        case Key_F23: return String(localized: "F23")
        case Key_F24: return String(localized: "F24")
        case Key_F25: return String(localized: "F25")
        case Key_F26: return String(localized: "F26")
        case Key_F27: return String(localized: "F27")
        case Key_F28: return String(localized: "F28")
        case Key_F29: return String(localized: "F29")
        case Key_F30: return String(localized: "F30")
        case Key_F31: return String(localized: "F31")
        case Key_F32: return String(localized: "F32")
        case Key_F33: return String(localized: "F33")
        case Key_F34: return String(localized: "F34")
        case Key_F35: return String(localized: "F35")
            
        case Key_Up:
            return String(localized: "Up Arrow")
        case Key_Down:
            return String(localized: "Down Arrow")
        case Key_Left:
            return String(localized: "Left Arrow")
        case Key_Right:
            return String(localized: "Right Arrow")
            
        case Key_Enter:
            return String(localized: "Enter")
        case Key_Escape:
            return String(localized: "Escape")
        case Key_Space:
            return String(localized: "Space")
        case Key_Tab:
            return String(localized: "Tab")
        case Key_BackSpace:
            return String(localized: "Backspace")
            
        case Key_Insert:
            return String(localized: "Insert")
        case Key_Delete:
            return String(localized: "Delete")
        case Key_PageUp:
            return String(localized: "Page Up")
        case Key_PageDown:
            return String(localized: "Page Down")
        case Key_Home:
            return String(localized: "Home")
        case Key_End:
            return String(localized: "End")
            
        case Key_CapsLock:
            return String(localized: "Caps Lock")
        case Key_ScrollLock:
            return String(localized: "Scroll Lock")
        case Key_PrintScreen:
            return String(localized: "Print Screen")
        case Key_Pause:
            return String(localized: "Pause")
        case Key_NumLock:
            return String(localized: "Num Lock")
        case Key_Clear:
            return String(localized: "Clear")
            
        case Key_Keypad0: return String(localized: "Keypad 0")
        case Key_Keypad1: return String(localized: "Keypad 1")
        case Key_Keypad2: return String(localized: "Keypad 2")
        case Key_Keypad3: return String(localized: "Keypad 3")
        case Key_Keypad4: return String(localized: "Keypad 4")
        case Key_Keypad5: return String(localized: "Keypad 5")
        case Key_Keypad6: return String(localized: "Keypad 6")
        case Key_Keypad7: return String(localized: "Keypad 7")
        case Key_Keypad8: return String(localized: "Keypad 8")
        case Key_Keypad9: return String(localized: "Keypad 9")
            
        case Key_KeypadDivide:
            return String(localized: "Keypad Divide")
        case Key_KeypadMultiply:
            return String(localized: "Keypad Multiply")
        case Key_KeypadSubtract:
            return String(localized: "Keypad Subtract")
        case Key_KeypadAdd:
            return String(localized: "Keypad Add")
        case Key_KeypadDecimal:
            return String(localized: "Keypad Decimal")
        case Key_KeypadEnter:
            return String(localized: "Keypad Enter")
            
        case Key_A: return String(localized: "A")
        case Key_B: return String(localized: "B")
        case Key_C: return String(localized: "C")
        case Key_D: return String(localized: "D")
        case Key_E: return String(localized: "E")
        case Key_F: return String(localized: "F")
        case Key_G: return String(localized: "G")
        case Key_H: return String(localized: "H")
        case Key_I: return String(localized: "I")
        case Key_J: return String(localized: "J")
        case Key_K: return String(localized: "K")
        case Key_L: return String(localized: "L")
        case Key_M: return String(localized: "M")
        case Key_N: return String(localized: "N")
        case Key_O: return String(localized: "O")
        case Key_P: return String(localized: "P")
        case Key_Q: return String(localized: "Q")
        case Key_R: return String(localized: "R")
        case Key_S: return String(localized: "S")
        case Key_T: return String(localized: "T")
        case Key_U: return String(localized: "U")
        case Key_V: return String(localized: "V")
        case Key_W: return String(localized: "W")
        case Key_X: return String(localized: "X")
        case Key_Y: return String(localized: "Y")
        case Key_Z: return String(localized: "Z")
            
        case Key_Number0: return String(localized: "0")
        case Key_Number1: return String(localized: "1")
        case Key_Number2: return String(localized: "2")
        case Key_Number3: return String(localized: "3")
        case Key_Number4: return String(localized: "4")
        case Key_Number5: return String(localized: "5")
        case Key_Number6: return String(localized: "6")
        case Key_Number7: return String(localized: "7")
        case Key_Number8: return String(localized: "8")
        case Key_Number9: return String(localized: "9")
            
        case Key_Tilde:
            return String(localized: "Tilde (~)")
        case Key_Grave:
            return String(localized: "Grave Accent (`)")
        case Key_Minus:
            return String(localized: "Minus (-)")
        case Key_Plus:
            return String(localized: "Plus (+)")
        case Key_BracketLeft:
            return String(localized: "Left Bracket ([)")
        case Key_BracketRight:
            return String(localized: "Right Bracket (])")
        case Key_Semicolon:
            return String(localized: "Semicolon (;)")
        case Key_Quote:
            return String(localized: "Quote (')")
        case Key_Comma:
            return String(localized: "Comma (,)")
        case Key_Period:
            return String(localized: "Period (.)")
        case Key_Slash:
            return String(localized: "Slash (/)")
        case Key_BackSlash:
            return String(localized: "Backslash (\\)")
        case Key_Unbound:
            return String(localized: "Unbound")
        default: return ""
        }
    }
}
