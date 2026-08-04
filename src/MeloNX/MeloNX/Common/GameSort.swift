//
//  GameSort.swift
//  MeloNX
//
//  Created by Stossy11 on 19/7/2026.
//

import Foundation

enum GameSort: String, Codable, CaseIterable {
    case alphabetical
    case newest
    case none
    
    var displayName: String {
        switch self {
        case .alphabetical:
            return "Alphabetical"
        case .newest:
            return "Newest"
        case .none:
            return "None"
        }
    }
}
