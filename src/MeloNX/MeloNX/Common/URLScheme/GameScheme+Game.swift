//
//  GameScheme+Game.swift
//  MeloNX
//
//  Created by Stossy11 on 14/12/2025.
//

import Foundation
import UIKit

extension GameScheme {
    init(_ game: GameInfo) {
        self.titleName = game.titleName
        self.titleId = game.titleId
        self.developer = game.developer
        self.version = game.version
        if let image = game.icon?.jpegData(compressionQuality: 0.5) {
            self.iconData = image
        } else {
            self.iconData = game.iconData
        }

    }
}
