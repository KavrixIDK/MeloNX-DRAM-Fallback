//
//  StatisticsHandler.swift
//  MeloNX
//
//  Created by Stossy11 on 26/5/2026.
//

import SwiftUI
import Foundation
import Combine

private struct StatisticsRequest: Codable {
    let FPS: Double
    let FrameTime: Double
    let Started: Bool
    let FIFO: Double
}

class StatisticsHandler: ObservableObject {
    @Published var fps: Double = 0
    @Published var frameTime: Double = 0
    @Published var started: Bool = false
    @Published var fifo: Double = 0
    
    func registerPush() {
        CallbackManager.register(name: "push_statistics") { data in
            guard let ptr = data.ptr, data.len >= 33 else { return }
            
            let fps = ptr.load(fromByteOffset: 0, as: Double.self)
            let frameTime = ptr.load(fromByteOffset: 8, as: Double.self)
            let started = ptr.load(fromByteOffset: 16, as: UInt8.self) != 0
            let fifo = ptr.load(fromByteOffset: 17, as: Double.self)
            
            Task {
                await MainActor.run {
                    self.fps       = fps
                    self.frameTime = frameTime
                    self.started   = started
                    self.fifo      = fifo
                }
            }
        }
    }
    
    func formatFPS() -> String {
        String(format: "FPS: %.2f", fps)
    }
}
