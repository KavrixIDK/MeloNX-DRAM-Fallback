//
//  UpdateManagerSheet.swift
//  MeloNX
//
//  Created by Stossy11 on 20/5/2026.
//


import SwiftUI
import UniformTypeIdentifiers
import Combine

struct UpdateManagerSheet: View {
    @EnvironmentObject var ryujinxController: RyujinxController
    @State private var updates: [UpdateItem] = []
    var game: GameInfo?
    @State private var jsonURL: URL? = nil
    @Environment(\.dismiss) var dismiss
    
    class UpdateItem: Identifiable, ObservableObject {
        let id = UUID()
        let url: URL
        let filename: String
        let relativePath: String
        
        @Published var isSelected: Bool = false
        
        init(url: URL, filename: String, relativePath: String, isSelected: Bool = false) {
            self.url = url
            self.filename = filename
            self.relativePath = relativePath
            self.isSelected = isSelected
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if updates.isEmpty {
                    emptyStateView
                } else {
                    ForEach(updates) { update in
                        updateRow(update)
                    }
                    .onDelete(perform: removeUpdates)
                }
            }
            .navigationTitle("\(game?.titleName ?? "Game") Updates")
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
                        Label("Add Update", systemImage: "plus")
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
                    "No Updates Found",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap the + button to add game updates.")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No Updates Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Tap the + button to add game updates.")
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
    
    private func updateRow(_ update: UpdateItem) -> some View {
        Group {
            if #available(iOS 15, *) {
                updateRowNew(update)
            } else {
                updateRowOld(update)
            }
        }
    }
    
    @available(iOS 15, *)
    private func updateRowNew(_ update: UpdateItem) -> some View {
        Button {
            toggleSelection(update)
        } label: {
            HStack {
                Text(update.filename)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: update.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(update.isSelected ? .primary : .secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = updates.firstIndex(where: { $0.relativePath == update.relativePath }) {
                    removeUpdate(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func updateRowOld(_ update: UpdateItem) -> some View {
        Button {
            toggleSelection(update)
        } label: {
            HStack {
                Text(update.filename)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: update.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(update.isSelected ? .primary : .secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button {
                if let index = updates.firstIndex(where: { $0.relativePath == update.relativePath }) {
                    removeUpdate(at: IndexSet(integer: index))
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
            .appendingPathComponent("updates.json")
        
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
            
            guard
                let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let paths = jsonDict["paths"] as? [String],
                let selected = jsonDict["selected"] as? String
            else { return }
            
            let validPaths = paths.filter { relativePath in
                FileManager.default.fileExists(
                    atPath: URL.documentsDirectory.appendingPathComponent(relativePath).path
                )
            }
            
            updates = validPaths.map { relativePath in
                let url = URL.documentsDirectory.appendingPathComponent(relativePath)
                return UpdateItem(
                    url: url,
                    filename: url.lastPathComponent,
                    relativePath: relativePath,
                    isSelected: selected == relativePath
                )
            }
        } catch {
            print("Failed to read JSON: \(error)")
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
            let defaultData: [String: Any] = ["selected": "", "paths": [String]()]
            let data = try JSONSerialization.data(withJSONObject: defaultData, options: .prettyPrinted)
            try data.write(to: jsonURL)
            updates = []
        } catch {
            print("Failed to create default JSON: \(error)")
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var newUpdates: [UpdateItem] = []
            
            for selectedURL in urls {
                guard let game = game,
                      selectedURL.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource")
                    continue
                }
                
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                do {
                    let fileManager = FileManager.default
                    let gameUpdatesDirectory = URL.documentsDirectory
                        .appendingPathComponent("updates")
                        .appendingPathComponent(game.titleId)
                    
                    try fileManager.createDirectory(at: gameUpdatesDirectory, withIntermediateDirectories: true)
                    
                    let filename = selectedURL.lastPathComponent
                    let relativePath = "updates/\(game.titleId)/\(filename)"
                    let destinationURL = URL.documentsDirectory.appendingPathComponent(relativePath)
                    
                    guard !updates.contains(where: { $0.relativePath == relativePath }) else {
                        print("Update already exists: \(filename)")
                        continue
                    }
                    
                    try? fileManager.removeItem(at: destinationURL)
                    try fileManager.copyItem(at: selectedURL, to: destinationURL)
                    
                    newUpdates.append(UpdateItem(
                        url: destinationURL,
                        filename: filename,
                        relativePath: relativePath,
                        isSelected: false
                    ))
                } catch {
                    print("Error copying update file: \(error)")
                }
            }
            
            guard !newUpdates.isEmpty else { return }
            
            if !updates.contains(where: { $0.isSelected }) {
                newUpdates[0].isSelected = true
            }
            
            updates.append(contentsOf: newUpdates)
            saveJSON()
            ryujinxController.loadGames()
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    private func toggleSelection(_ update: UpdateItem) {
        let nowSelected = !update.isSelected
        updates.forEach { $0.isSelected = $0.relativePath == update.relativePath && nowSelected }
        saveJSON()
    }
    
    private func removeUpdates(at offsets: IndexSet) {
        offsets.forEach { removeUpdate(at: IndexSet(integer: $0)) }
    }
    
    private func removeUpdate(at indexSet: IndexSet) {
        guard let index = indexSet.first else { return }
        
        let updateToRemove = updates[index]
        
        do {
            try FileManager.default.removeItem(at: updateToRemove.url)
            updates.remove(at: index)
            saveJSON()
            ryujinxController.loadGames()
        } catch {
            print("Failed to remove update: \(error)")
        }
    }
    
    private func saveJSON() {
        guard let jsonURL = jsonURL else { return }
        
        do {
            let jsonDict: [String: Any] = [
                "paths": updates.map { $0.relativePath },
                "selected": updates.first(where: { $0.isSelected })?.relativePath ?? ""
            ]
            let data = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
            try data.write(to: jsonURL)
        } catch {
            print("Failed to save JSON: \(error)")
        }
    }
}
