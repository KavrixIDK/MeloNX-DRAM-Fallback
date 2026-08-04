//
//  FileImporter.swift
//  MeloNX
//
//  Created by Stossy11 on 17/04/2025.
//

import UIKit
import Combine
import UniformTypeIdentifiers

class FileImporterManager: NSObject, ObservableObject, UIDocumentPickerDelegate {
    static let shared = FileImporterManager()
    
    private var currentCompletion: ((Result<[URL], Error>) -> Void)?
    private var currentDocumentPicker: UIDocumentPickerViewController?
    private var securityScopedURLs: [URL] = []
    
    private override init() {
        super.init()
    }
    
    func importFiles(
        types fullTypes: [UTType],
        allowMultiple: Bool = false,
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        self.currentCompletion = { result in
           Task { @MainActor in
                completion(result)
               self.stopAccessingSecurityScopedResources()
            }
        }
        
        var types = fullTypes
    
        let needsAsCopy = types == [.folder] ? false : AppEnvironment.shared.needsAsCopy
        if types.contains(.folder), needsAsCopy {
            types.removeAll(where: { $0 == .folder })
        }
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: needsAsCopy)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = allowMultiple
        documentPicker.modalPresentationStyle = .formSheet
        
        self.currentDocumentPicker = documentPicker
        
        guard let topViewController = getTopViewController() else {
            print("Failed to get top view conntroller")
            let error = NSError(
                domain: "FileImporterManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to find presenting view controller."]
            )
            currentCompletion?(.failure(error))
            return
        }
        
        DispatchQueue.main.async {
            topViewController.present(documentPicker, animated: true)
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return nil
        }
        return topMost(of: rootViewController)
    }

    private func topMost(of viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topMost(of: presented)
        }
        
        if let nav = viewController as? UINavigationController,
           let visible = nav.visibleViewController {
            return topMost(of: visible)
        }
        
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMost(of: selected)
        }
        
        return viewController
    }
    
    private func stopAccessingSecurityScopedResources() {
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll()
    }
    
    private func cleanup() {
        currentCompletion = nil
        currentDocumentPicker = nil
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var accessibleURLs: [URL] = []
        
        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                securityScopedURLs.append(url)
                accessibleURLs.append(url)
            } else {
                accessibleURLs.append(url)
            }
        }
        
        currentCompletion?(.success(accessibleURLs))
        cleanup()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let error = NSError(
            domain: "FileImporterManager",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled the document picker."]
        )
        currentCompletion?(.failure(error))
        cleanup()
    }
}

extension FileImporterManager {
    
    func importSingleFile(completion: @escaping (Result<URL, Error>) -> Void) {
        importFiles(types: [.item], allowMultiple: false) { result in
            switch result {
            case .success(let urls):
                if let firstURL = urls.first {
                    completion(.success(firstURL))
                } else {
                    completion(.failure(NSError(domain: "FileImporterManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No file selected."])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func importMultipleFiles(completion: @escaping (Result<[URL], Error>) -> Void) {
        importFiles(types: [.item], allowMultiple: true, completion: completion)
    }
    
    func importImages(allowMultiple: Bool = false, completion: @escaping (Result<[URL], Error>) -> Void) {
        importFiles(types: [.image], allowMultiple: allowMultiple, completion: completion)
    }
    
    func importDocuments(allowMultiple: Bool = false, completion: @escaping (Result<[URL], Error>) -> Void) {
        let documentTypes: [UTType] = [.pdf, .plainText, .rtf, .html, .xml, .json]
        importFiles(types: documentTypes, allowMultiple: allowMultiple, completion: completion)
    }
}
