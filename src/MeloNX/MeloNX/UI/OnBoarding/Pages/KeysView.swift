//
//  KeysView.swift
//  MeloNX
//
//  Created by Stossy11 on 6/7/2026.
//

import SwiftUI
import UniformTypeIdentifiers

enum Keys: String, CaseIterable {
    case prod
    case title
    
    var fileName: String {
        "\(rawValue).keys"
    }
    
    static func keyForFile(_ file: URL) -> Keys? {
        Keys.allCases.first(where: { $0.fileName == file.lastPathComponent })
    }
}

struct KeysView: View {
    var goForward: () -> Void
    
    var fileImporter: FileImporterManager = .shared
    let ryujinxController: RyujinxController = .shared
    let fileManager: FileManager = .default
    
    let destination: URL = .keysFolderURL
    
    @State var keysAdded: Bool = false
    @State var onlyProdAdded: Bool = false
    
    
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
                
                Text("Import Encryption Keys (prod.keys & title.keys).\nRequired to be dumped from a Modded Nintendo Switch.")
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
                    ContinueButton(text: "Continue", action: goForward2, success: onlyProdAdded, enabled: .constant(onlyProdAdded || keysAdded), showCheckmark: false, baseColor: onlyProdAdded ? .orange : .green)
                        .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                            view
                                .padding(.bottom)
                        }
                }
        }
    }
    
    func goForward2() {
        guard onlyProdAdded else { goForward(); return }
        
        AppAlerts.showSyncAlert(title: "Missing File", message: "title.keys recommended. Continue at your own risk.", hasCancel: true) { text in
            switch text {
            case "OK": goForward()
            default: break
            }
        }
    }
    
    func importKeys() {
        fileImporter.importFiles(types: [.item], allowMultiple: true) { result in
            switch result {
            case .success(let urls):
                var unsupportedFiles: [String] = []
                var invalidFiles: [String] = []
                var failedCopies: [String] = []

                for url in urls {
                    let fileName = url.lastPathComponent

                    guard Keys.allCases.compactMap(\.fileName).contains(fileName) else {
                        unsupportedFiles.append(fileName)
                        continue
                    }

                    guard ryujinxController.verifyKeysFile(path: url) else {
                        invalidFiles.append(fileName)
                        continue
                    }

                    do {
                        let destinationURL: URL = .keysFolderURL.appendingPathComponent(fileName)

                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }

                        try fileManager.copyItem(at: url, to: destinationURL)
                    } catch {
                        failedCopies.append("\(fileName): \(error.localizedDescription)")
                    }
                }

                checkForKeys()

                var messages: [String] = []

                if !unsupportedFiles.isEmpty {
                    messages.append("Only prod.keys and title.keys are supported here. Ignored: \(unsupportedFiles.joined(separator: ", "))")
                }

                if !invalidFiles.isEmpty {
                    messages.append("Invalid key file format: \(invalidFiles.joined(separator: ", "))")
                }

                if !failedCopies.isEmpty {
                    messages.append("Failed to copy: \(failedCopies.joined(separator: ", "))")
                }

                if !messages.isEmpty {
                    AppAlerts.showSyncAlert(title: "Import Keys Failed", message: messages.joined(separator: "\n\n"), hasCancel: false)
                }
                
            case .failure(let failure):
                AppAlerts.showSyncAlert(title: "Import Failed", message: failure.localizedDescription, hasCancel: false)
            }
        }
    }
    
    func checkFor(_ key: Keys) -> Bool {
        ryujinxController.verifyKeysFile(path: .keysFolderURL, keys: key)
    }
    
    func checkForKeys() {
        let prod = checkFor(.prod)
        let title = checkFor(.title)
        
        keysAdded = prod && title
        onlyProdAdded = prod && !title
        
        Ryujinx.reloadKeySet()
    }
}

extension RyujinxController {
    func verifyKeysFile(path parentPath: URL, keys: Keys) -> Bool {
        let genericPattern = "^[a-z0-9_]+ = [a-z0-9]+$"
        let titlePattern = "^[a-z0-9]{32} = [a-z0-9]{32}$"
        
        let path = (parentPath.lastPathComponent != keys.fileName && parentPath.hasDirectoryPath) ? parentPath.appendingPathComponent(keys.fileName) : parentPath
        
        print(path)
        
        guard FileManager.default.fileExists(atPath: path.path) else { return false }
        
        return switch keys {
        case .prod: verifyKeys(for: path.path, pattern: genericPattern)
        case .title: verifyKeys(for: path.path, pattern: titlePattern)
        }
    }
    
    func verifyKeysFile(path: URL) -> Bool {
        let genericPattern = "^[a-z0-9_]+ = [a-z0-9]+$"
        let titlePattern = "^[a-z0-9]{32} = [a-z0-9]{32}$"
        
        guard FileManager.default.fileExists(atPath: path.path) else { return false }
        
        return switch Keys.keyForFile(path) {
        case .prod: verifyKeys(for: path.path, pattern: genericPattern)
        case .title: verifyKeys(for: path.path, pattern: titlePattern)
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
