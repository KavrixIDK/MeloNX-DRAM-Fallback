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
        AppEnvironment.shared.lcBundle?.bundleIdentifier ?? Bundle.main.bundleIdentifier
    }
}

class AppEnvironment {
    var isInLiveContainer: Bool
    var needsAsCopy: Bool
    var isInMultitask: Bool
    var lcBundle: Bundle?
    
    static var shared: AppEnvironment = .init()
    
    init() {
        if let lc = Self.liveContainer() {
            self.isInLiveContainer = true
            self.isInMultitask = lc.1
            self.lcBundle = lc.0
            self.needsAsCopy = Bundle.main.hostBundleIdentifier != Bundle.main.bundleIdentifier ? true : false
        } else {
            self.isInLiveContainer = false
            self.isInMultitask = false
            self.lcBundle = nil
            self.needsAsCopy = false
            let hostIdentifier = Self.getModifiedHostIdentifier(originalHostIdentifier: "")
            if hostIdentifier != Bundle.main.bundleIdentifier! {
                self.needsAsCopy = true
            }
        }
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
                    
                    ryujinxController.loadGames()
                    let game = ryujinxController.games.first {
                        $0.titleId == query || $0.titleName == query
                    }
                    
                    if let game {
                        ryujinxController.startGame(game)
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
}

extension Data {
    public func base64urlEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
