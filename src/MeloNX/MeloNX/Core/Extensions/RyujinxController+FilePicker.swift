//
//  RyujinxController+FilePicker.swift
//  MeloNX
//
//  Created by Stossy11 on 30/4/2026.
//

import Foundation
import UIKit
import Combine

extension RyujinxController {
    public func handleRunningGame(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            
            _ = url.startAccessingSecurityScopedResource()
            
            do {
                let handle = try FileHandle(forReadingFrom: url)
                let fileExtension = (url.pathExtension as NSString)
                
                let gameInfo = Ryujinx.getGameInfo(arg0: handle.fileDescriptor, arg1: fileExtension, path: url)
                
                self.startGame(gameInfo)
            } catch {
            }
            
        case .failure(let err):
            print("File import failed: \(err.localizedDescription)")
        }
    }
    
    
    public func handleAddingGame(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            
            let cool = url.startAccessingSecurityScopedResource()
            defer { cool ? url.stopAccessingSecurityScopedResource() : () }
            
            do {
                if !GameFileType.isSupported(fileExtension: url.pathExtension) {
                    AppAlerts.showSyncAlert(title: "Failed to import", message: "Unsupported file extension")
                    return
                }
                
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let romsDirectory = documentsDirectory.appendingPathComponent("roms")
                
                if !fileManager.fileExists(atPath: romsDirectory.path) {
                    try? fileManager.createDirectory(at: romsDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let destinationURL = romsDirectory.appendingPathComponent(url.lastPathComponent)
                try fileManager.copyItem(at: url, to: destinationURL)
                
                self.loadGames()
            } catch {
                AppAlerts.showSyncAlert(title: "Failed to import", message: error.localizedDescription)
            }
        case .failure(let err):
            AppAlerts.showSyncAlert(title: "Failed to import", message: err.localizedDescription)
        }
    }
    
    public func handleFirmwareImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let url):
            guard let url = url.first else {
                return
            }
            
            do {
                let path = url.path
                
                try Ryujinx.installFirmware(at: path)
                objectWillChange.send()
                _ = firmwareVersion
            } catch FirmwareInstallationError.failedInstall(let string) {
                AppAlerts.showSyncAlert(title: "Installing Firmware Failed", message: string, hasCancel: false)
            } catch {
                AppAlerts.showSyncAlert(title: "Installing Firmware Failed", message: error.localizedDescription, hasCancel: false)
            }
        case .failure(let error):
            AppAlerts.showSyncAlert(title: "Installing Firmware Failed", message: error.localizedDescription, hasCancel: false)
        }
    }
    
    public func clearShaderCache(_ titleId: String = "") {
        AppAlerts.showAlert(title: "Clear Shader Cache", message: titleId.isEmpty ? "Are you sure you want to clear ALL shader cache?" : "Are you sure you want to clear your shader cache?",
                  actions: [
                    (title: "Cancel", style: .cancel, handler: nil),
                    (title: "Clear", style: .destructive, handler: {
                        self.clearShaderCacheImpl(titleId)
                    }),
                  ]
        )
        
    }
    
    private func clearShaderCacheImpl(_ titleId: String) {
        if titleId.isEmpty {
            let fileManager = FileManager.default
            let gamesURL = URL.documentsDirectory.appendingPathComponent("games")
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: gamesURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                
                let folderURLs = contents.filter { url in
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
                
                for folderURL in folderURLs {
                    try? fileManager.removeItem(at: folderURL.appendingPathComponent("cache"))
                }
                
            } catch {
                print("Error reading games folder: \(error)")
            }
        } else {
            let fileManager = FileManager.default
            let cacheURL = URL.documentsDirectory.appendingPathComponent("games").appendingPathComponent(titleId).appendingPathComponent("cache")
            
            try? fileManager.removeItem(at: cacheURL)
        }
    }
}
