//
//  RyujinxController.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import SwiftUI
import Combine

extension URL {
    @available(iOS, introduced: 14.0, deprecated: 16.0, message: "Use URL.documentsDirectory on iOS 16 and above")
    static var documentsDirectory: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory
    }
    
    static var configFolderURL: URL {
        documentsDirectory.appendingPathComponent("config")
    }
    
    static func perGameConfigURL(_ titleId: String) -> URL {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configFolderURL.path) {
            try? fileManager.createDirectory(at: configFolderURL, withIntermediateDirectories: true)
        }
        
        return configFolderURL.appendingPathComponent(titleId + "_config.json")
    }
    
    static var configURL: URL {
        documentsDirectory.appendingPathComponent("config.json")
    }
    
    static var romsURL: URL {
        documentsDirectory.appendingPathComponent("roms")
    }
    
    static var keyboardConfigURL: URL {
        documentsDirectory.appendingPathComponent("keyboardConfig.json")
    }
    
    static var keysFolderURL: URL {
        documentsDirectory.appendingPathComponent("system")
    }
    
    static var modsFolderURL: URL {
        documentsDirectory.appendingPathComponent("mods")
    }
    
    static func modFolderURL(for game: GameInfo) -> URL {
        modsFolderURL.appendingPathComponent("contents").appendingPathComponent(game.titleId)
    }
}

extension UIDevice {
    var supportsBCTextureCompression: Bool {
        if #available(iOS 16.4, *), let device = MTLCreateSystemDefaultDevice() {
           return device.supportsBCTextureCompression
        }
        
        return false
    }
}

enum StartedState {
    case none
    case entitlement
    case extendedEntitlement
    case noJIT
    case usersList
}

enum RunningState {
    case started(game: GameInfo, state: StartedState = .none)
    case stopped
    case crashed(result: String)
    
    func hasStarted() -> Bool {
        if case .started(_, let state) = self {
            return state != .noJIT
        }
        return false
    }
    
    func isRunning() -> Bool {
        if case .started(_, let state) = self {
            return state == .none
        }
        return false
    }
    
    func isEntitlement() -> Bool {
        if case .started(_, let state) = self {
            return state == .entitlement
        }
        return false
    }
    
    func hasCrashed() -> Bool {
        if case .crashed = self {
            return true
        }
        return false
    }
}



class RyujinxController: ObservableObject {
    static var shared: RyujinxController = .init()
    
    private init() {}
    
    @Published var isRunning: RunningState = .stopped
    @Published var games: [GameInfo] = []
    @Published var settings: Options = .init(inputPath: "")
    
    @Published var perSettings: [String: Options] = [:]
    
    var currentSettings: Options {
        get {
            if case .started(let game, _) = isRunning {
                return perSettings[game.titleId] ?? settings
            }
            
            return settings
        } set {
            self.objectWillChange.send()
            if case .started(let game, _) = isRunning, perSettings[game.titleId]  != nil {
                perSettings[game.titleId] = newValue
            }
            
            settings = newValue
        }
    }
    
    var lastGameLaunched: String? {
        get {
            UserDefaults.standard.string(forKey: "lastGameLaunched")
        } set {
            if let cool = newValue { UserDefaults.standard.set(newValue, forKey: "lastGameLaunched"); return }
            UserDefaults.standard.removeObject(forKey: "lastGameLaunched")
        }
    }
    
    @Published var _isPaused: Bool = false
    
    @Published var wasManuallyPaused: Bool = false
    
    var isPaused: Bool {
        get {
            return _isPaused
        } set {
            _isPaused = newValue
            Ryujinx.togglePauseEmulation(_isPaused)
        }
    }
    
    private static var hasScript: Bool = false
    private var controllerManager: ControllerManager = .shared
    private var emulationThreadActive = false
    
    var firmwareVersion: String {
        return Ryujinx.installedFirmwareVersion
    }
    
    var firmwareInstalled: Bool {
        !Ryujinx.installedFirmwareVersion.isEmpty
    }
    
    var isJITEnabled: Bool {
        jitEnabled()
    }
    
    var hasIncreasedMemoryLimitEntitlement: Bool {
        checkAppEntitlement("com.apple.developer.kernel.increased-memory-limit")
    }
    
    var hasExtendedVirtualAddressingEntitlement: Bool {
        checkAppEntitlement("com.apple.developer.kernel.extended-virtual-addressing")
    }
    
    
    
    func startGame(_ game: GameInfo) {
        guard !emulationThreadActive, !isRunning.hasStarted() else { return }
        
        loadConfig()
        
        if !hasIncreasedMemoryLimitEntitlement {
            isRunning = .started(game: game, state: .entitlement)
            lastGameLaunched = nil
            return
        }
        
        if !hasExtendedVirtualAddressingEntitlement && AppEnvironment.shared.requiresExtendedVirtualAddressing() {
            isRunning = .started(game: game, state: .extendedEntitlement)
            lastGameLaunched = nil
            return
        }
        
        // extendedEntitlement
        
        if !isJITEnabled {
            isRunning = .started(game: game, state: .noJIT)
            return
        }
        
        lastGameLaunched = nil
        
        let config = pullKeyboardConfig()
        Ryujinx.setKeyboardConfig(config)
        
        controllerManager.attachAllControllers()
        
        if NativeSettingsManager.exists(game.titleId) {
            print("true")
            NativeSettingsManager.setShared(game.titleId, pullOriginal: true)
        }
        
        loadWithoutSave(game.titleId)
        
        var settings = perSettings[game.titleId] ?? settings
        
        settings.inputPath = game.fileURL.path
        settings.backendThreading = .on
        
        isRunning = .started(game: game)
        _isPaused = false
        wasManuallyPaused = false
        emulationThreadActive = true
        
        let nativeSettingsManager = NativeSettingsManager.shared
        
        if !(nativeSettingsManager.writeStdout.value as Bool) {
            redirectStdIOToFile()
        }
        
        Thread.detachNewThread {
            let response = Ryujinx.mainRyu(settings)
            
            DispatchQueue.main.async {
                self.emulationThreadActive = false
                
                if response != 0 {
                    self.isRunning = .crashed(result: "Code: \(response)")
                } else {
                    self.isRunning = .stopped
                }
            }
        }
    }
    
    
    func redirectStdIOToFile() {
        let fileManager = FileManager.default
        
        let logsDir = URL.documentsDirectory.appendingPathComponent("logs")
        
        if !fileManager.fileExists(atPath: logsDir.path) {
            try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }
        
        cleanupOldLogs(in: logsDir, keep: 5)
        
        let fileName = "MeloNX-Log-\(Date()).log"
        let logURL = logsDir.appendingPathComponent(fileName)
        
        fileManager.createFile(atPath: logURL.path, contents: nil)
        
        let fd = open(logURL.path, O_WRONLY | O_APPEND, 0o644)
        guard fd >= 0 else { return }
        
        dup2(fd, STDOUT_FILENO)
        dup2(fd, STDERR_FILENO)
        
        close(fd)
    }
    
    func cleanupOldLogs(in directory: URL, keep: Int) {
        let fileManager = FileManager.default
        
        guard var files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        files = files.compactMap({ $0.lastPathComponent.hasPrefix("MeloNX-Log-") ? $0 : nil })
        
        let sortedFiles = files.sorted {
            let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return date1 > date2
        }
        
        let filesToDelete = sortedFiles.dropFirst(keep)
        
        for file in filesToDelete {
            try? fileManager.removeItem(at: file)
        }
    }
    
    func loadConfig() {
        if let settings = try? Options.loadFromJSON(at: .configURL) {
            self.settings = settings
        } else {
            try? self.settings.saveAsJSON(to: .configURL)
        }
    }
    
    func saveConfig() {
        try? settings.saveAsJSON(to: .configURL)
    }
    
    func loadPerGameConfig(_ titleId: String) {
        let setting2s = perSettings[titleId] ??  .init(inputPath: "")
        if let settings = try? Options.loadFromJSON(at: .perGameConfigURL(titleId)) {
            self.perSettings[titleId] = settings
        } else {
            try? setting2s.saveAsJSON(to: .perGameConfigURL(titleId))
            self.perSettings[titleId] = .init(inputPath: "")
        }
    }
    
    func loadWithoutSave(_ titleId: String) {
        if let settings = try? Options.loadFromJSON(at: .perGameConfigURL(titleId)) {
            self.perSettings[titleId] = settings
        }
    }
    
    func savePerGameConfig(_ titleId: String) {
        let setting2s = perSettings[titleId] ??  .init(inputPath: "")
        try? setting2s.saveAsJSON(to: .perGameConfigURL(titleId))
    }
    
    func loadGames() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        var romDirectories: [URL] = [documentsDirectory.appendingPathComponent("roms")]
        
        let romFolderManager = ROMFolderManager.shared
        romFolderManager.loadBookmarks()
        
        for bookmarkData in romFolderManager.bookmarks {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale, fileManager.fileExists(atPath: url.path) {
                    _ = romFolderManager.addFolder(url: url)
                }
                
                if url.startAccessingSecurityScopedResource() {
                    romDirectories.append(url)
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
        
        let defaultRomsDirectory = documentsDirectory.appendingPathComponent("roms")
        if !fileManager.fileExists(atPath: defaultRomsDirectory.path) {
            do {
                try fileManager.createDirectory(at: defaultRomsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create roms directory: \(error)")
            }
        }
        
        var games: [GameInfo] = []
        for romsDirectory in romDirectories {
            guard let enumerator = fileManager.enumerator(at: romsDirectory, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for case let fileURL as URL in enumerator {
                guard GameFileType.isSupported(fileExtension: fileURL.pathExtension) else { continue }
                
                do {
                    let handle = try FileHandle(forReadingFrom: fileURL)
                    let fileExtension = fileURL.pathExtension as NSString
                    games.append(Ryujinx.getGameInfo(arg0: handle.fileDescriptor, arg1: fileExtension, path: fileURL))
                } catch {
                    print("Failed to read file at \(fileURL): \(error)")
                }
            }
        }
        
        self.games = games
        
        sortGames(true)
    }
    
    func sortGames(_ isCalled: Bool = false) {
        let nativeSettingsManager: NativeSettingsManager = .shared
        switch nativeSettingsManager.gameSort(GameSort.none).value {
        case .alphabetical:
            games = games.sorted { $0.titleName < $1.titleName }
        case .newest:
            games = games.sorted { (game, gam2) -> Bool in
                let date1 = (try? game.fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let date2 = (try? gam2.fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                
                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
            }
        case .none:
            if !isCalled { loadGames() }
        }
    }
    
    static func attemptToMapDualMapping() -> Bool {
        if hasScript { return true }
        
        hasScript = Ryujinx.initDualMapping()
        
        return hasScript
    }
    
    func attemptToMapDualMapping() -> Bool {
        Self.attemptToMapDualMapping()
    }
}
