//
//  KeysView.swift
//  MeloNX
//
//  Created by Stossy11 on 6/7/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct KeysView: View {
    var goForward: () -> Void
    
    var fileImporter: FileImporterManager = .shared
    let ryujinxController: RyujinxController = .shared
    let fileManager: FileManager = .default
    
    let destination: URL = .keysFolderURL
    let keys: [String] = [
        "prod.keys", "title.keys"
    ]
    
    @State var keysAdded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center) {
                Spacer()
                    .frame(height: 110)
                
                Image(systemName: "key.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 120))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 120)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .blue.opacity(0.6),
                                        .red.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 6)
                
                Text("Import Keys")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding()
                
                Text("Import Encryption Keys.\nRequired to be dumped from a Modded Nintendo Switch.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                ContinueButton(text: "Import", action: importKeys, success: keysAdded, enabled: .constant(!keysAdded))
                    .padding()
            }
        }
        .padding()
        .onAppear(perform: checkForKeys)
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
            Color.clear
                .frame(height: 80)
                .ignoresSafeArea()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                        .frame(width: .infinity, height: .infinity)
                )
                .overlay(alignment: .bottom) {
                    ContinueButton(text: "Continue", action: goForward, enabled: .constant(true))
                        .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                            view
                                .padding(.bottom)
                        }
                }
        }
    }
    
    func importKeys() {
        fileImporter.importFiles(types: [.item], allowMultiple: true) { result in
            switch result {
            case .success(let success):
                for url in success {
                    guard keys.contains(url.lastPathComponent) else { continue }
                    
                    if !ryujinxController.verifyKeysFile(path: url) {
                        AppAlerts.showSyncAlert(title: "Invalid Keys", message: "Input file is not a valid key package")
                    }
                    
                    do {
                        if fileManager.fileExists(atPath: URL.keysFolderURL.appendingPathComponent(url.lastPathComponent).path) {
                            try? fileManager.removeItem(at: .keysFolderURL.appendingPathComponent(url.lastPathComponent))
                        }
                        
                        try fileManager.copyItem(at: url, to: .keysFolderURL.appendingPathComponent(url.lastPathComponent))
                    } catch { AppAlerts.showSyncAlert(title: "Import Failed", message: error.localizedDescription) }
                }
                
                
                checkForKeys()
                
            case .failure(let failure):
                AppAlerts.showSyncAlert(title: "Import Failed", message: failure.localizedDescription)
            }
        }
    }
    
    func checkForKeys() {
        let prod = ryujinxController.verifyKeysFile(path: .keysFolderURL.appendingPathComponent(keys[0]))
        let title = ryujinxController.verifyKeysFile(path: .keysFolderURL.appendingPathComponent(keys[1]))
        
        keysAdded = prod && title
        
        Ryujinx.reloadKeySet()
    }
}

extension RyujinxController {
    func verifyKeysFile(path: URL) -> Bool {
        let genericPattern = "^[a-z0-9_]+ = [a-z0-9]+$"
        let titlePattern = "^[a-z0-9]{32} = [a-z0-9]{32}$"
        
        return switch path.lastPathComponent {
        case "prod.keys": verifyKeys(for: path.path, pattern: genericPattern)
        case "title.keys": verifyKeys(for: path.path, pattern: titlePattern)
        default: false
        }
    }
    
    func verifyKeys(for path: String, pattern: String) -> Bool {
        let data = try? String(contentsOfFile: path, encoding: .utf8)
        let myStrings = (data ?? "").components(separatedBy: .newlines).filter({ !$0.isEmpty })
        guard !myStrings.isEmpty else { return false }
        
        for string in myStrings {
            if !string.matches(pattern) {
                return false
            }
        }
        
        return true
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
