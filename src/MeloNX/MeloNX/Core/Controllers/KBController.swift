//
//  KBController.swift
//  MeloNX
//
//  Created by Stossy11 on 10/6/2026.
//

import Foundation
import GameController

class KBController: BaseController {
    override var pointer: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: 1)! - 1
    }
    
    override init(nativeController: GCController? = nil, virtual: Bool? = nil) {
        super.init(nativeController: nativeController)
        self.orgName = "Keyboard Controller"
        self.virtual = false
    }
}
