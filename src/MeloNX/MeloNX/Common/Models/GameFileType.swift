//
//  GameFileType.swift
//  MeloNX
//
//  Created by Stossy11 on 18/07/2025.
//

import Foundation

enum GameFileType: String, CaseIterable {
    case nro
    case nsp
    case xci
    case nca
    case pfs0
    case romfs // not needed just kept just because ryu has support for them
    case istorage // not needed just kept just because ryu has support for them
    
    static func isSupported(fileExtension: String) -> Bool {
        return GameFileType.allCases.contains { $0.rawValue.lowercased() == fileExtension.lowercased() }
    }
}
