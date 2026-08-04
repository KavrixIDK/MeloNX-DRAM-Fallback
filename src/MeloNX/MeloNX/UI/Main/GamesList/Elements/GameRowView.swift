//
//  GameRowView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct GameRowView: View {
    let game: GameInfo
    @EnvironmentObject var ryujinxController: RyujinxController
    @State var gametoDelete: GameInfo?
    @State var showGameDeleteConfirmation: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.appTheme) var theme
    
    @AppStorage("portal") var gamepo = false
    
    var body: some View {
        Button(action: {
            ryujinxController.startGame(game)
        }) {
            HStack(spacing: 16) {
                // Game Icon
                if let icon = game.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 55, height: 55)
                        .cornerRadius(10)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ?
                                  Color(.systemGray5) : Color(.systemGray6))
                            .frame(width: 55, height: 55)
                        
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                
                // Game Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.titleName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(game.developer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        if !game.version.isEmpty && game.version != "0" {
                            Divider().frame(width: 1, height: 15)
                            
                            Text("v\(game.version)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.accent.primary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .confirmationDialog("Are you sure you want to delete this game?", isPresented: $showGameDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let game = gametoDelete {
                    deleteGame(game: game)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(gametoDelete?.titleName ?? "this game")?")
        }
        .listRowInsets(EdgeInsets())
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        
    }
    
    private func deleteGame(game: GameInfo) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: game.fileURL)
            ryujinxController.games.removeAll { $0.id == game.id }
        } catch {
            // print("Error deleting game: \(error)")
        }
    }
}
