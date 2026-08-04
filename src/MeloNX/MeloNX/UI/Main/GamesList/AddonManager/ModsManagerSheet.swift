//
//  ModsManagerSheet.swift
//  MeloNX
//
//  Created by Stossy11 on 16/02/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct Mod: Codable {
    var name: String
    var path: String
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case path = "Path"
        case enabled = "Enabled"
    }
}

struct ModMetadata: Codable {
    var mods: [Mod]

    enum CodingKeys: String, CodingKey {
        case mods = "Mods"
    }

    init(mods: [Mod] = []) {
        self.mods = mods
    }
}

struct ModsManagerSheet: View {
    @State private var mods: [ModItem] = []
    var game: GameInfo?
    @State private var modsURL: URL? = nil
    @Environment(\.dismiss) var dismiss
    
    class ModItem: Identifiable, ObservableObject {
        let id = UUID()
        let url: URL
        let filename: String
        let path: String
        @Published var enabled: Bool
        
        init(url: URL, filename: String, path: String, enabled: Bool = true) {
            self.url = url
            self.filename = filename
            self.path = path
            self.enabled = enabled
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Please note that mods currently have limited support and may not work or behave correctly.")
                        .foregroundStyle(.red)
                        .font(.caption.bold())
                }
                
                Section {
                    if mods.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(mods) { update in
                            updateRow(update)
                        }
                        .onDelete(perform: removeUpdates)
                    }
                }
            }
            .navigationTitle("\(game?.titleName ?? "Game") Mods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FileImporterManager.shared.importFiles(types: [.folder], allowMultiple: true, completion: handleFileImport)
                    } label: {
                        Label("Add Mod", systemImage: "plus")
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
                    "No Mods Found",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap the + button to add game mods.")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Mods Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap the + button to add game mods.")
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
    
    
    private func updateRow(_ update: ModItem) -> some View {
        HStack {
            Button {
                AppAlerts.showAlert(title: "Delete", message: "Would you like to delete \(update.filename)?", actions: [
                    (title: "Cancel", style: .cancel, handler: nil),
                    (title: "Delete", style: .destructive, handler: {
                        if let index = mods.firstIndex(where: { $0.path == update.path }) {
                            removeUpdate(at: IndexSet(integer: index))
                        }
                    })
                ])
            } label: {
                HStack {
                    Text(update.filename)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Toggle("", isOn: Binding(
                get: { update.enabled },
                set: { newValue in
                    update.enabled = newValue
                    saveModMetadata()
                }
            ))
            .labelsHidden()
        }
        .contextMenu {
            Button(role: .destructive) {
                if let index = mods.firstIndex(where: { $0.path == update.path }) {
                    removeUpdate(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = mods.firstIndex(where: { $0.path == update.path }) {
                    removeUpdate(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func modMetadataURL(for titleId: String) -> URL {
        let modsRoot = URL.documentsDirectory.appendingPathComponent("mods")
        let metadataDir = modsRoot.appendingPathComponent("metadata")
        try? FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        return metadataDir.appendingPathComponent("\(titleId).json")
    }
    
    private func loadModMetadata(for titleId: String) -> ModMetadata {
        let url = modMetadataURL(for: titleId)
        
        guard let data = try? Data(contentsOf: url) else { return .init() }
        
        do {
            return try JSONDecoder().decode(ModMetadata.self, from: data)
        } catch {
            print("Failed to decode mods.json for \(titleId): \(error)")
            return ModMetadata()
        }
    }
    
    private func saveModMetadata() {
        guard let game = game else { return }
        
        let metadata = ModMetadata(mods: mods.map {
            Mod(name: $0.filename, path: $0.path, enabled: $0.enabled)
        })
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: modMetadataURL(for: game.titleId), options: .atomic)
        } catch {
            print("Failed to write mods.json: \(error)")
        }
    }
    
    private func loadData() {
        guard let game = game else { return }
        
        let documentsDirectory = URL.documentsDirectory
        let cool =  documentsDirectory
            .appendingPathComponent("mods")
            .appendingPathComponent("contents")
            .appendingPathComponent(game.titleId)
        modsURL = cool
        
        let metadata = loadModMetadata(for: game.titleId)
        
        let contents = (try? FileManager.default.contentsOfDirectory(at: cool, includingPropertiesForKeys: nil)) ?? []
        for fileURL in contents {
            let relativePath = "mods/\(game.titleId)/\(fileURL.lastPathComponent)"
            let savedMod = metadata.mods.first(where: { $0.path == relativePath })
            let newUpdate = ModItem(
                url: fileURL,
                filename: fileURL.lastPathComponent,
                path: relativePath,
                enabled: savedMod?.enabled ?? true
            )
            
            mods.append(newUpdate)
        }
        
        saveModMetadata()
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var updates: [ModItem] = []
            for selectedURL in urls {
                guard let game = game,
                      selectedURL.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource")
                    return
                }
                
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                do {
                    let fileManager = FileManager.default
                    let updatesDirectory = URL.documentsDirectory.appendingPathComponent("mods")
                    let contentsDirectory = updatesDirectory.appendingPathComponent("contents")
                    let gameModsDirectory = contentsDirectory.appendingPathComponent(game.titleId)
                    
                    try? fileManager.createDirectory(at: gameModsDirectory, withIntermediateDirectories: true)
                    
                    try? fileManager.removeItem(at: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent))
                    try fileManager.copyItem(at: selectedURL, to: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent))
                    
                    let relativePath = "mods/\(game.titleId)/\(selectedURL.lastPathComponent)"
                    let newUpdate = ModItem(
                        url: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent),
                        filename: selectedURL.lastPathComponent,
                        path: relativePath,
                        enabled: true
                    )
                    
                    updates.append(newUpdate)
                    
                } catch {
                    print("Error copying update file: \(error)")
                }
            }
            
            
            self.mods.append(contentsOf: updates)
            saveModMetadata()
            
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    private func removeUpdates(at offsets: IndexSet) {
        offsets.forEach { removeUpdate(at: IndexSet(integer: $0)) }
    }
    
    private func removeUpdate(at indexSet: IndexSet) {
        guard let index = indexSet.first else { return }
        
        let updateToRemove = mods[index]
        
        do {
            try FileManager.default.removeItem(at: updateToRemove.url)
            
            mods.remove(at: index)
            saveModMetadata()
        } catch {
            print("Failed to remove update: \(error)")
        }
    }
}
