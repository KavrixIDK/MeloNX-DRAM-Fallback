//
//  AlertHandlers.swift
//  MeloNX
//
//  Created by Stossy11 on 23/4/2026.
//

import UIKit
import Foundation


private struct AlertRequest: Decodable {
    let title: String
    let message: String
    let cancel: Bool
}

enum AlertHandlers {
    static func register() {
        registerTextInput()
        registerAlert()
    }
    
    private static func registerTextInput() {
        CallbackManager.register(name: "show_text_input") { data in
            guard let ptr = data.ptr, data.len > 0 else { return }
            
            let bytes = Data(bytesNoCopy: ptr, count: Int(data.len), deallocator: .none)
            guard let request = try? JSONDecoder().decode(TextInputRequest.self, from: bytes) else {
                print("[AlertHandlers] show_text_input: failed to decode request")
                return
            }
            
            DispatchQueue.main.async {
                presentTextInput(request)
            }
        }
    }
    
    private static func presentTextInput(_ request: TextInputRequest) {
        let alert = UIAlertController(
            title:   request.title,
            message: request.message,
            preferredStyle: .alert
        )
        
        alert.addTextField { field in
            field.placeholder       = request.placeholder
            field.autocorrectionType = .no
        }
        
        print(request.callbackId)
        
        let resultName = "show_text_input_result_\(request.callbackId)"
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            let text = alert.textFields?.first?.text ?? ""
            invokeStringCallback(name: resultName, value: text)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            invokeEmptyCallback(name: resultName)
        })
        
        topViewController()?.present(alert, animated: true)
    }
    
    private static func registerAlert() {
        CallbackManager.register(name: "show_alert") { data in
            guard let ptr = data.ptr, data.len > 0 else { return }
            
            let bytes = Data(bytesNoCopy: ptr, count: Int(data.len), deallocator: .none)
            guard let request = try? JSONDecoder().decode(AlertRequest.self, from: bytes) else {
                print("[AlertHandlers] show_alert: failed to decode request")
                return
            }
            
            DispatchQueue.main.async {
                presentAlert(request)
            }
        }
    }
    
    private static func presentAlert(_ request: AlertRequest) {
        let alert = UIAlertController(
            title:   request.title,
            message: request.message,
            preferredStyle: .alert
        )
        
        
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if request.cancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        }
        
        topViewController()?.present(alert, animated: true)
    }
    
    private static func invokeStringCallback(name: String, value: String) {
        guard let bytes = value.data(using: .utf8) else {
            invokeEmptyCallback(name: name)
            return
        }
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else {
                invokeEmptyCallback(name: name)
                return
            }
            name.withCString { nameCStr in
                _ = InvokeCallback(nameCStr, base, Int32(bytes.count))
            }
        }
    }
    
    
    private static func invokeEmptyCallback(name: String) {
        name.withCString { nameCStr in
            _ = InvokeCallback(nameCStr, nil, 0)
        }
    }
    
    
    public static func topWindow() -> UIWindow {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })
        else { return UIApplication.shared.keyWindow! }
        return root
    }
    
    
    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    
}

