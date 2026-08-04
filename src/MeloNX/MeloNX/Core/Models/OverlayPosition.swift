//
//  OverlayPosition.swift
//  MeloNX
//
//  Created by Stossy11 on 26/5/2026.
//

import Foundation
import SwiftUI

enum PerformanceOverlayPosition: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case topCenter
    case bottomLeft
    case bottomRight
    case bottomCenter
    
    var displayValue: String {
        switch self {
        case .topLeft:
            return String(localized: "Top Left")
        case .topRight:
            return String(localized: "Top Right")
        case .topCenter:
            return String(localized: "Top Center")
        case .bottomLeft:
            return String(localized: "Bottom Left")
        case .bottomRight:
            return String(localized: "Bottom Right")
        case .bottomCenter:
            return String(localized: "Bottom Center")
        }
    }
    
    var alignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .topCenter:
            return .top
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        case .bottomCenter:
            return .bottom
        }
    }
}
