//
//  AppEnvironment.swift
//  MeloNX
//
//  Created by Stossy11 on 23/4/2026.
//

import UIKit
import UniformTypeIdentifiers
import Foundation
import ObjectiveC.runtime
import Security

extension Bundle {
    var hostBundleIdentifier: String? {
        AppEnvironment.lcBundle?.bundleIdentifier ?? Bundle.main.bundleIdentifier
    }
}

class AppEnvironment {
    var isInLiveContainer: Bool
    var needsAsCopy: Bool
    var isInMultitask: Bool
    static var lcBundle: Bundle?
    var lcBundle: Bundle? {
        Self.lcBundle
    }
    
    static var shared: AppEnvironment = .init()
    
    init() {
        if let lc = Self.liveContainer() {
            self.isInLiveContainer = true
            self.isInMultitask = lc.1
            Self.lcBundle = lc.0
            let needsAsCopy = Bundle.main.hostBundleIdentifier != Bundle.main.bundleIdentifier
            
            if needsAsCopy {
                Self.swizzleInstanceMethod(
                    for: NSClassFromString("DOCConfiguration")!,
                    original: NSSelectorFromString("setHostIdentifier:"),
                    swizzled: #selector(DOCConfigurationLC.hook_setHostIdentifier(_:))
                )
            }
            
            self.needsAsCopy = false
        } else {
            self.isInLiveContainer = false
            self.isInMultitask = false
            Self.lcBundle = nil
            self.needsAsCopy = false
            let hostIdentifier = Self.getModifiedHostIdentifier(originalHostIdentifier: "")
            if hostIdentifier != Bundle.main.bundleIdentifier! {
                self.needsAsCopy = true
                
                Self.swizzleInstanceMethod(
                    for: NSClassFromString("DOCConfiguration")!,
                    original: NSSelectorFromString("setHostIdentifier:"),
                    swizzled: #selector(DOCConfigurationLC.hook_setHostIdentifier(_:))
                )
            }
        }
    }
    
    var _requiresVirtualAddressing: Bool? = nil
    
    func requiresExtendedVirtualAddressing() -> Bool {
        if let _requiresVirtualAddressing { return _requiresVirtualAddressing }
        
        let fourGB = 4 * 1024 * 1024 * 1024

        let addr = mmap(nil, fourGB, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0)
        
        _requiresVirtualAddressing = addr == MAP_FAILED
        
        return addr == MAP_FAILED ? true : munmap(addr, fourGB) != 0;
    }
    
    static private func liveContainer() -> (Bundle?, Bool)? {
        if let cls = NSClassFromString("NSUserDefaults") as? NSObject.Type {
            let selector = NSSelectorFromString("lcMainBundle")
            var bundle: Bundle?
            var isDone: Bool = false
            
            if cls.responds(to: selector),
               let result = cls.perform(selector)?.takeUnretainedValue() as? Bundle {
                bundle = result
            } else {
                return nil
            }
            
            if let result = cls.value(forKey: "isLiveProcess") as? Bool {
                isDone = result
            } else {
                return (bundle, false)
            }
            
            return (bundle, isDone)
        }
        
        return nil
    }
    
    static private func getModifiedHostIdentifier(originalHostIdentifier: String) -> String {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return originalHostIdentifier
        }
        
        var error: NSError?
        let appIdRef = SecTaskCopyValueForEntitlement(task, "application-identifier" as NSString, &error)
        releaseSecTask(task)
        
        guard let appId = appIdRef as? String, CFGetTypeID(appIdRef) == CFStringGetTypeID() else {
            return originalHostIdentifier
        }
        
        if let dotRange = appId.range(of: ".") {
            return String(appId[dotRange.upperBound...])
        }
        
        return appId
    }
    
    static func handleDeepLink(_ url: URL, ryujinxController: RyujinxController) {
        Task {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
            
            switch components.host {
            case "game":
                let idMatch = components.queryItems?.first(where: { $0.name == "id" })?.value
                let nameMatch = components.queryItems?.first(where: { $0.name == "name" })?.value
                
                if let query = idMatch ?? nameMatch {
                    let nativeSettingsManager: NativeSettingsManager = .shared
                    ryujinxController.loadGames()
                    let game = ryujinxController.games.first {
                        $0.titleId == query || $0.titleName == query
                    }
                    
                    if let game {
                        if ryujinxController.isJITEnabled {
                            ryujinxController.startGame(game)
                        } else {
                            ryujinxController.lastGameLaunched = game.titleId
                            let jitProv = nativeSettingsManager.jitProvider(JITProvider.disabled).value
                            if jitProv == .disabled {
                                ryujinxController.startGame(game)
                            } else {
                                EnableJIT.enableJIT(jitProv)
                            }
                        }
                    }
                }
                
            case "gameInfo":
                guard let urlscheme = components.queryItems?.first(where: { $0.name == "scheme" })?.value,
                      let data = try? JSONEncoder().encode(ryujinxController.games.map { GameScheme($0) }) else { return }
                
                let encoded = data.base64urlEncodedString()
                let scheme = url.scheme ?? "melonx"
                if let returnURL = URL(string: "\(urlscheme)://\(scheme)?games=\(encoded)") {
                    await UIApplication.shared.open(returnURL)
                    if !ryujinxController.isJITEnabled {
                        exit(0)
                    }
                }
            default:
                return
            }
        }
    }
    
    static func swizzleInstanceMethod(
        for cls: AnyClass,
        original originalSelector: Selector,
        swizzled swizzledSelector: Selector
    ) {
        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    static func swizzleClassMethod(
        for cls: AnyClass,
        original originalSelector: Selector,
        swizzled swizzledSelector: Selector
    ) {
        guard let metaClass = object_getClass(cls),
            let originalMethod = class_getClassMethod(cls, originalSelector),
            let swizzledMethod = class_getClassMethod(cls, swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(metaClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(metaClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

@objc
class DOCConfigurationLC: NSObject {
    @objc func hook_setHostIdentifier(_ ignored: NSString) {
        guard let task = SecTaskCreateFromSelf(nil) else {
            hook_setHostIdentifier(ignored)
            return
        }
        
        var error: NSError?
        let appIdRef = SecTaskCopyValueForEntitlement(task, "application-identifier" as NSString, &error)
        releaseSecTask(task)
        
        if let appIdRef, var entString: String = appIdRef as? String {
            CFRelease(appIdRef)
            
            if let dotRange = entString.range(of: ".") {
                entString = String(entString[dotRange.upperBound...])
            }
            
            hook_setHostIdentifier(entString as NSString)
        } else {
            if let appIdRef { CFRelease(appIdRef) }
            print("Error fetching entitlement: \(error?.localizedDescription ?? "Unknown error")")
            hook_setHostIdentifier(ignored)
        }
    }
}

extension Data {
    public func base64urlEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
