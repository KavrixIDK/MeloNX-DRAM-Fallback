//
//  BaseController+Motion.swift
//  MeloNX
//
//  Created by Stossy11 on 16/11/2025.
//

import Foundation
import CoreMotion
import GameController
import UIKit

extension BaseController {
    func setupMotion() {
        if let nativeController, nativeController.motion != nil, !self.usesDeviceHandlers {
            nativeController.motion?.sensorsActive = true
            
            // Thank you @BXYMartin :3
            nativeController.motion?.valueChangedHandler = { [weak self] m in
                guard let self = self else { return }
                let rawAccelX = Float(m.acceleration.x)
                let rawAccelY = Float(m.acceleration.y)
                let rawAccelZ = Float(m.acceleration.z)

                let rawGyroDeg = SIMD3<Float>(
                    Float(m.rotationRate.x),
                    Float(m.rotationRate.y),
                    Float(m.rotationRate.z)
                ) * 180.0 / .pi

                let accel = SIMD3(-rawAccelX, -rawAccelZ, rawAccelY)
                let gyro = SIMD3(rawGyroDeg.x, rawGyroDeg.z, -rawGyroDeg.y)

                self.submitMotion(accelerometer: accel, gyroscope: gyro)
            }
        } else {
            guard self.motionManager.isDeviceMotionAvailable else { return }

            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60Hz
            self.motionManager.startDeviceMotionUpdates(to: self.motionOperation) { [weak self] (data, error) in
                guard let self = self, let m = data else { return }

                let rawAccel = SIMD3<Float>(
                    -Float(m.gravity.x + m.userAcceleration.x),
                    -Float(m.gravity.y + m.userAcceleration.y),
                    -Float(m.gravity.z + m.userAcceleration.z)
                )
                
                let rawGyro = SIMD3<Float>(
                    Float(m.rotationRate.x),
                    -Float(m.rotationRate.y),
                    -Float(m.rotationRate.z)
                ) * (180.0 / .pi)

                let (mappedAccel, mappedGyro) = self.remapToSwitchCoords(accel: rawAccel, gyro: rawGyro)
                self.submitMotion(accelerometer: mappedAccel, gyroscope: mappedGyro)
            }
        }
    }

    func stopMotion() {
        nativeController?.motion?.valueChangedHandler = nil
        nativeController?.motion?.sensorsActive = false

        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    private func submitMotion(accelerometer: SIMD3<Float>, gyroscope: SIMD3<Float>) {
        motionQueue.async {
            Ryujinx.setGamepadMotion(self.pointer, motionType: 1, axis: accelerometer)
            Ryujinx.setGamepadMotion(self.pointer, motionType: 2, axis: gyroscope)
        }
    }

    private func remapToSwitchCoords(accel: SIMD3<Float>, gyro: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        let orientation = currentMotionOrientation()

        var finalAccel: SIMD3<Float>
        var finalGyro: SIMD3<Float>

        switch orientation {
        case .landscapeLeft:
            finalAccel = SIMD3<Float>(accel.y, -accel.x, accel.z)
            finalGyro = SIMD3<Float>(gyro.y, -gyro.x, gyro.z)
        case .landscapeRight:
            finalAccel = SIMD3<Float>(-accel.y, accel.x, accel.z)
            finalGyro = SIMD3<Float>(-gyro.y, gyro.x, gyro.z)
        case .portraitUpsideDown:
            finalAccel = SIMD3<Float>(-accel.x, accel.z, accel.y)
            finalGyro = SIMD3<Float>(-gyro.x, gyro.z, gyro.y)
        default:
            finalAccel = SIMD3<Float>(accel.x, accel.z, -accel.y)
            finalGyro = SIMD3<Float>(gyro.x, gyro.z, -gyro.y)
        }

        return (finalAccel, finalGyro)
    }

    private func currentMotionOrientation() -> UIDeviceOrientation {
        let currentOrientation = UIDevice.current.orientation

        if currentOrientation.isValidInterfaceOrientation {
            orientation = currentOrientation
        }

        return orientation
    }
}
