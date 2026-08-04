//
//  GameScheme.swift
//  MeloNX
//
//  Created by Stossy11 on 22/5/2026.
//

// GameScheme.swift can be dropped into any swift app and be used as normal
// GameScheme+Game.swift is used only for the MeloNX game struct
import Foundation

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    var bundleId: String? = Bundle.main.hostBundleIdentifier // new item for JIT enablement
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}
