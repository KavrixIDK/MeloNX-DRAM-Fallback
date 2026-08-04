//
//  DLCManagerSheet.swift
//  MeloNX
//
//  Created by Stossy11 on 1/6/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct DLCManagerSheet: View {
    @EnvironmentObject var ryujinxController: RyujinxController
    @State private var dlcs: [DLCItem] = []
    var game: GameInfo?
    @State private var jsonURL: URL? = nil
    @Environment(\.dismiss) var dismiss
    
    class DLCItem: Identifiable, ObservableObject {
        let id = UUID()
        let url: URL
        let filename: String
        let relativePath: String
        var ncaList: [DownloadableContentNca]
        
        @Published var isEnabled: Bool
        
        init(url: URL, filename: String, relativePath: String, ncaList: [DownloadableContentNca], isEnabled: Bool = false) {
            self.url = url
            self.filename = filename
            self.relativePath = relativePath
            self.ncaList = ncaList
            self.isEnabled = isEnabled
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if dlcs.isEmpty {
                    emptyStateView
                } else {
                    ForEach(dlcs) { dlc in
                        dlcRow(dlc)
                    }
                    .onDelete(perform: removeDLCs)
                }
            }
            .navigationTitle("\(game?.titleName ?? "Game") DLCs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FileImporterManager.shared.importFiles(
                            types: [.item],
                            allowMultiple: true,
                            completion: handleFileImport
                        )
                    } label: {
                        Label("Add DLC", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if #available(iOS 17, *) {
                ContentUnavailableView(
                    "No DLCs Found",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Tap the + button to add game DLCs.")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No DLCs Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Tap the + button to add game DLCs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
            }
        }
    }
    
    private func dlcRow(_ dlc: DLCItem) -> some View {
        Group {
            if #available(iOS 15, *) {
                dlcRowNew(dlc)
            } else {
                dlcRowOld(dlc)
            }
        }
    }
    
    @available(iOS 15, *)
    private func dlcRowNew(_ dlc: DLCItem) -> some View {
        Button {
            toggleDLC(dlc)
        } label: {
            HStack {
                Text(dlc.filename)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: dlc.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(dlc.isEnabled ? .primary : .secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = dlcs.firstIndex(where: { $0.relativePath == dlc.relativePath }) {
                    removeDLC(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func dlcRowOld(_ dlc: DLCItem) -> some View {
        Button {
            toggleDLC(dlc)
        } label: {
            HStack {
                Text(dlc.filename)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: dlc.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(dlc.isEnabled ? .primary : .secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button {
                if let index = dlcs.firstIndex(where: { $0.relativePath == dlc.relativePath }) {
                    removeDLC(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func loadData() {
        guard let game = game else { return }
        
        jsonURL = URL.documentsDirectory
            .appendingPathComponent("games")
            .appendingPathComponent(game.titleId)
            .appendingPathComponent("dlc.json")
        
        loadJSON()
    }
    
    private func loadJSON() {
        guard let jsonURL = jsonURL else { return }
        
        do {
            guard FileManager.default.fileExists(atPath: jsonURL.path) else {
                createDefaultJSON()
                return
            }
            
            let data = try Data(contentsOf: jsonURL)
            let containers = try JSONDecoder().decode([DownloadableContentContainer].self, from: data)
            
            dlcs = containers.compactMap { container in
                let url = URL.documentsDirectory.appendingPathComponent(container.containerPath)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                let isEnabled = container.downloadableContentNcaList.first?.enabled ?? false
                return DLCItem(
                    url: url,
                    filename: url.lastPathComponent,
                    relativePath: container.containerPath,
                    ncaList: container.downloadableContentNcaList,
                    isEnabled: isEnabled
                )
            }
        } catch {
            print("Failed to read DLC JSON: \(error)")
            createDefaultJSON()
        }
    }
    
    private func createDefaultJSON() {
        guard let jsonURL = jsonURL else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: jsonURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode([DownloadableContentContainer]())
            try data.write(to: jsonURL)
            dlcs = []
        } catch {
            print("Failed to create default DLC JSON: \(error)")
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var newDLCs: [DLCItem] = []
            
            for selectedURL in urls {
                guard let game = game else {
                    continue
                }

                let hasSecurityScope = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    let fileManager = FileManager.default
                    let gameDLCDirectory = URL.documentsDirectory
                        .appendingPathComponent("dlc")
                        .appendingPathComponent(game.titleId)
                    
                    try fileManager.createDirectory(at: gameDLCDirectory, withIntermediateDirectories: true)
                    
                    let filename = selectedURL.lastPathComponent
                    let relativePath = "dlc/\(game.titleId)/\(filename)"
                    let destinationURL = URL.documentsDirectory.appendingPathComponent(relativePath)
                    
                    guard !dlcs.contains(where: { $0.relativePath == relativePath }) else {
                        print("DLC already exists: \(filename)")
                        continue
                    }
                    
                    try? fileManager.removeItem(at: destinationURL)
                    try fileManager.copyItem(at: selectedURL, to: destinationURL)
                    
                    let ncaList = Ryujinx.getDlcNcaList(titleId: game.titleId, path: destinationURL.path)
                    guard !ncaList.isEmpty else {
                        print("No valid DLC content found for: \(filename)")
                        continue
                    }
                    
                    newDLCs.append(DLCItem(
                        url: destinationURL,
                        filename: filename,
                        relativePath: relativePath,
                        ncaList: ncaList,
                        isEnabled: false
                    ))
                } catch {
                    print("Error copying DLC file: \(error)")
                }
            }
            
            guard !newDLCs.isEmpty else { return }
            
            if !dlcs.contains(where: { $0.isEnabled }) {
                newDLCs[0].isEnabled = true
            }
            
            dlcs.append(contentsOf: newDLCs)
            saveJSON()
            ryujinxController.loadGames()
            
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    private func toggleDLC(_ dlc: DLCItem) {
        guard let index = dlcs.firstIndex(where: { $0.relativePath == dlc.relativePath }) else { return }
        dlcs[index].isEnabled.toggle()
        saveJSON()
    }
    
    private func removeDLCs(at offsets: IndexSet) {
        offsets.forEach { removeDLC(at: IndexSet(integer: $0)) }
    }
    
    private func removeDLC(at indexSet: IndexSet) {
        guard let index = indexSet.first else { return }
        
        let dlcToRemove = dlcs[index]
        
        do {
            try FileManager.default.removeItem(at: dlcToRemove.url)
            dlcs.remove(at: index)
            saveJSON()
            ryujinxController.loadGames()
        } catch {
            print("Failed to remove DLC: \(error)")
        }
    }
    
    private func saveJSON() {
        guard let jsonURL = jsonURL else { return }

        do {
            let containers = dlcs.map { dlc in
                DownloadableContentContainer(
                    containerPath: dlc.relativePath,
                    downloadableContentNcaList: dlc.ncaList.map { nca in
                        var mutableNca = nca
                        mutableNca.enabled = dlc.isEnabled
                        return mutableNca
                    }
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(containers)
            try data.write(to: jsonURL)
        } catch {
            print("Failed to save DLC JSON: \(error)")
        }
    }
}
