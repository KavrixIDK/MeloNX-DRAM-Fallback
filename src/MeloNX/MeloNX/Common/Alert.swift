//
//  Alert.swift
//  MeloNX
//
//  Created by Stossy11 on 30/4/2026.
//

import Foundation
import UIKit
import SwiftUI

class AppAlerts {
    static func topViewController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }
    
    static func showAlert(_ viewController: UIViewController? = nil,
                          title: String?,
                          message: String?,
                          actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)]) {
        
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for action in actions {
            let uiAction = UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            }
            alert.addAction(uiAction)
        }
        
        if Thread.isMainThread {
            let coolVC = viewController ?? UIApplication.shared.windows.first?.rootViewController!
            coolVC!.present(alert, animated: true, completion: nil)
        } else {
            DispatchQueue.main.async {
                let coolVC = viewController ?? UIApplication.shared.windows.first?.rootViewController!
                coolVC!.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @discardableResult
    static func showSyncAlert(
        title: String?,
        message: String?,
        actions: [String] = ["OK"],
        hasCancel: Bool = true,
        alertHandler: @escaping (String) -> Void = { _ in }
    ) -> UIAlertController? {
        
        guard let presenter = topViewController() else {
            fatalError("No Top Controller")
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for actionTitle in actions {
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                alertHandler(actionTitle)
            })
        }
        
        if hasCancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                alertHandler("Cancel")
            })
        }
        
        Task { @MainActor in
            presenter.present(alert, animated: true)
        }
        
        return alert
    }
    
    @MainActor
    static func showTextFieldAlert(
        title: String?,
        message: String?,
        default defaultText: String?,
        action: String = "OK",
    ) async -> String? {
        await withCheckedContinuation { continuation in
            guard let presenter = topViewController() else {
                continuation.resume(returning: "NoPresenter")
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField()
            
            alert.textFields![0].text = defaultText
            
            alert.addAction(UIAlertAction(title: action, style: .default) { _ in
                let answer = alert.textFields![0]
                
                continuation.resume(returning: answer.text)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: defaultText)
            })
            
            presenter.present(alert, animated: true)
        }
    }
    
    @MainActor
    static func showAlert(
        title: String?,
        message: String?,
        actions: [String] = ["OK"],
        hasCancel: Bool = true
    ) async -> String {
        
        await withCheckedContinuation { continuation in
            guard let presenter = topViewController() else {
                continuation.resume(returning: "NoPresenter")
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            for actionTitle in actions {
                alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                    continuation.resume(returning: actionTitle)
                })
            }
            
            if hasCancel {
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: "Cancel")
                })
            }
            
            presenter.present(alert, animated: true)
        }
    }
}

