//
//  GamesListView+ToolBar.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

extension GamesListView {
    func toolbarHandler() -> some ToolbarContent {
        if #available(iOS 19.0, *) {
            return Group {
                ToolbarItem(placement: .topBarTrailing) {
                    addGameButton
                }
                .sharedBackgroundVisibility(.hidden)
                
                ToolbarItem(placement: .topBarLeading) {
                    optionsSection
                }
                .sharedBackgroundVisibility(.hidden)
            }
        } else {
            return Group {
                ToolbarItem(placement: .topBarTrailing) {
                    addGameButton
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    optionsSection
                }
            }
        }
    }
    
    
    private var addGameButton: some View {
        Button {
            FileImporterManager.shared.importFiles(types: [.nsp, .xci, .item]) { result in
                ryujinxController.handleAddingGame(result: result)
            }
        } label: {
            Label("Add Game", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .semibold))
        }
        .accentColor(.blue)
    }

    private var optionsSection: some View {
        Menu {
            firmwareSection
            
            Divider()
            
            Button {
                FileImporterManager.shared.importFiles(types: [.nsp, .xci, .item]) { result in
                    ryujinxController.handleRunningGame(result: result)
                }
            } label: {
                Label("Open Game", systemImage: "square.and.arrow.down")
            }
            
            Button {
                let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                var sharedurl = documentsUrl.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
                if ProcessInfo.processInfo.isiOSAppOnMac {
                    sharedurl = documentsUrl.absoluteString
                }
                if UIApplication.shared.canOpenURL(URL(string: sharedurl)!) {
                    UIApplication.shared.open(URL(string: sharedurl)!, options: [:])
                }
            } label: {
                Label("Show MeloNX Folder", systemImage: "folder")
            }
            
            Divider()
            
            Button {
                self.activeSheet = .account
            } label: {
                Label("Profile Manager", systemImage: "person.2")
            }
            
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .foregroundColor(.blue)
        }
    }

    private var firmwareSection: some View {
        Group {
            if ryujinxController.firmwareInstalled {
                Button {
                    
                } label: {
                    Text("Firmware: \(ryujinxController.firmwareVersion)")
                }
                
                Menu("Applets") {
                    Button {
                        let game = GameInfo(containerFolder: URL(string: "none")!, fileType: .item, fileURL: URL(string: "0x0100000000001009")!, titleName: "Mii Maker", titleId: "0", developer: "Nintendo", version: ryujinxController.firmwareVersion)
                        self.ryujinxController.startGame(game)
                    } label: {
                        Label("Launch Mii Maker", systemImage: "person.crop.circle")
                    }
                }
            } else {
                Button {
                    FileImporterManager.shared.importFiles(types: [.folder, .zip, .xci]) { result in
                        ryujinxController.handleFirmwareImport(result: result)
                    }
                } label: {
                    Label("Install Firmware", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}

