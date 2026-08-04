//
//  VirtualControllerButton.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import Melo_Controller


extension VirtualControllerButton {
    private static let ordered: [VirtualControllerButton] = [
        .A,
        .B,
        .X,
        .Y,
        .back,
        .guide,
        .start,
        .leftStick,
        .rightStick,
        .leftShoulder,
        .rightShoulder,
        .dPadUp,
        .dPadDown,
        .dPadLeft,
        .dPadRight,
        .leftTrigger,
        .rightTrigger
    ]
    
    var rawValue: Int {
        guard let index = Self.ordered.firstIndex(where: { $0.id == self.id }) else {
            fatalError("Unknown VirtualControllerButton id: \(id)")
        }
        return Int(index)
    }
}
