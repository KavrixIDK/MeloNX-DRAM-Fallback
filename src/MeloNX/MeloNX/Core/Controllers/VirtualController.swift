//
//  ControllerManager.swift
//  MeloNX
//
//  Created by Stossy11 on 8/3/2026.
//

import Foundation
import Combine
import Melo_Controller

public class VirtualControllerManager: ObservableObject, Controller {
    static var shared = VirtualControllerManager()
    let controller = ControllerManager.shared.virtualController
    public func buttonPressed(_ button: VirtualControllerButton) {
        controller.setButtonState(1, for: button)
    }
    
    public func buttonReleased(_ button: VirtualControllerButton) {
        controller.setButtonState(0, for: button)
    }
    
    public func joystickMoved(position: CGPoint, right: Bool) {
        controller.thumbstickMoved(right ? .right : .left, x: position.x, y: position.y)
    }
}
