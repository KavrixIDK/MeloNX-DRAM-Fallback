//
//  RomFolderManager.swift
//  MeloNX
//
//  Created by Stossy11 on 31/07/2025.
//

import Foundation
import SwiftUI
import Combine


let withSecurityScope = URL.BookmarkResolutionOptions(rawValue: 1 << 10)

class ROMFolderManager: ObservableObject {
    
    private let bookmarksKey = "ROMFolderManagerBookmarks"
    @Published var bookmarks: [Data] = [] {
        didSet {
            saveBookmarks()
        }
    }
    
    private init() {
        loadBookmarks()
    }
    
    static var shared = ROMFolderManager()
    
    func addFolder(url: URL) -> Bool {
        let options = URL.BookmarkCreationOptions(rawValue: 1 << 11)
        do {
            let bookmark = try url.bookmarkData(options: options,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            bookmarks.append(bookmark)
            saveBookmarks()
            return true
        } catch {
            print("Failed to create bookmark: \(error)")
            return false
        }
    }
    
    func getUrl(from bookmark: Data) -> URL? {
        var isStale = false
        
        
        do {
            var url = try URL(
                resolvingBookmarkData: bookmark,
                options: withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("stale")
                
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let options = URL.BookmarkCreationOptions(rawValue: 1 << 11)
                let newBookmark = try url.bookmarkData(
                    options: options,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                if let index = bookmarks.firstIndex(where: { $0 == bookmark }) {
                    bookmarks[index] = newBookmark
                } else {
                    bookmarks.append(newBookmark)
                }
                
                print("Bookmark refreshed and saved.")
            }
            
            return url
            
        } catch {
            print("Error resolving bookmark:", error)
            return nil
        }
    }

    
    
    func stopAccessingFolder(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    private func saveBookmarks() {
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
    
    func loadBookmarks() {
        if let saved = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] {
            bookmarks = saved
        } else if let saved = UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] {
            bookmarks = Array(saved.values)
            saveBookmarks()
        }
    }
}
