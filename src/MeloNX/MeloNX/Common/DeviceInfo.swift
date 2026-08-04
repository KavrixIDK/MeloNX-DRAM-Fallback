//
//  DeviceInfo.swift
//  MeloNX
//
//  Created by Stossy11 on 23/4/2026.
//

import UIKit
import Foundation
import Security
import MobileCoreServices

typealias MGCopyAnswerFunc = @convention(c) (CFString) -> CFPropertyList?

func MGCopyAnswer(_ key: CFString) -> CFPropertyList? {
    struct Static {
        static var handle: UnsafeMutableRawPointer? = {
            dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY)
        }()
        
        static var function: MGCopyAnswerFunc? = {
            guard let handle = handle else { return nil }
            let sym = dlsym(handle, "MGCopyAnswer")
            return unsafeBitCast(sym, to: MGCopyAnswerFunc?.self)
        }()
    }
    
    guard let fn = Static.function else {
        return nil
    }
    
    return fn(key)
}

let kMGPhysicalHardwareNameString = "PhysicalHardwareNameString" as CFString

func getPhysicalHardwareName() -> String? {
    MGCopyAnswer(kMGPhysicalHardwareNameString) as? String
}

public extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return getPhysicalHardwareName() ?? identifier
    }()

}
