//
//  OrientationManager.swift
//  MeloNX
//
//  Created by Stossy11 on 18/07/2025.
//


import UIKit

class OrientationManager {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, rotateTo rotateOrientation: UIInterfaceOrientation) {
        AlertHandlers.topWindow().overrideUserInterfaceStyle = .unspecified
        
        AppDelegate.orientationLock = orientation
        
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, rotateTo rotateOrientation: UIDeviceOrientation) {
        AlertHandlers.topWindow().overrideUserInterfaceStyle = .unspecified
        
        AppDelegate.orientationLock = orientation
        
        UIDevice.current.setValue(interfaceOrientation(from: rotateOrientation).rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    
    static func lockCurrentOrientation(_ orientation: UIDeviceOrientation) {
        AlertHandlers.topWindow().overrideUserInterfaceStyle = .unspecified
        
        AppDelegate.orientationLock = interfaceOrientationMask(from: orientation)
        
        UIDevice.current.setValue(interfaceOrientation(from: orientation).rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    
    private static func interfaceOrientation(from deviceOrientation: UIDeviceOrientation) -> UIInterfaceOrientation {
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft 
        default:
            return .portrait
        }
    }
    
    private static func interfaceOrientationMask(from deviceOrientation: UIDeviceOrientation) -> UIInterfaceOrientationMask {
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
}
