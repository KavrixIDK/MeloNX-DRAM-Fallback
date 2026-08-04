//
//  GameInfo.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import Foundation
import UniformTypeIdentifiers
import UIKit

public struct GameInfo: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: URL { fileURL }

    var containerFolder: URL
    var fileType: UTType
    var fileURL: URL

    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    var icon: UIImage? {
        UIImage(data: iconData ?? Data())
    }
    
    init(containerFolder: URL, fileType: UTType, fileURL: URL, titleName: String, titleId: String, developer: String, version: String, iconData: Data? = nil) {
        self.containerFolder = containerFolder
        self.fileType = fileType
        self.fileURL = fileURL
        self.titleName = titleName
        self.titleId = titleId
        self.developer = developer
        self.version = version
        self.iconData = iconData
    }
    
    init(_ gameInfo: GameInfoC, url: URL) {
        self.containerFolder = url.deletingLastPathComponent()
        self.fileURL = url
        self.fileType = .item
        
        self.titleName = withUnsafePointer(to: gameInfo.TitleName) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        self.developer = withUnsafePointer(to: gameInfo.Developer) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        self.titleId = withUnsafePointer(to: gameInfo.TitleId) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        self.version = withUnsafePointer(to: gameInfo.Version) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
    
        self.iconData = createImage(from: gameInfo)
        
        free_game_info(gameInfo)
    }
    
    
    
    func createImage(from gameInfo: GameInfoC) -> Data? {
       let imageSize = Int(gameInfo.ImageSize)
       if imageSize > 0, imageSize <= 1024 * 1024 {
           return Data(bytes: gameInfo.ImageData, count: imageSize)
       }
       return nil
    }
}
