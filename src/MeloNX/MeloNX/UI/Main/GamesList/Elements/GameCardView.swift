//
//  GameCardView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI


struct GameCardView: View {
    @EnvironmentObject var ryujinxController: RyujinxController
    @StateObject var nativeSettings = NativeSettingsManager.shared
    let game: GameInfo
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.appTheme) var theme
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    var cardType: CardType {
        nativeSettings.cardLayout(CardType.card).value
    }
    
    @ViewBuilder
    var smallGrid: some View {
        if let icon = game.icon {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                .frame(width: 150, height: 150)
            
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    var wiiUCard: some View {
        Group {
            if let icon = game.icon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 95, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    .frame(width: 95, height: 95)
                
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(
                    color: Color(.darkGray).opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        }
    }
    
    var body: some View {
        Button {
            ryujinxController.startGame(game)
        } label: {
            if cardType == .compactCard || cardType == .compactCardNoBackground {
                smallGrid
                    .if(cardType == .compactCard) { view in
                        view
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: Color(.darkGray).opacity(colorScheme == .dark ? 0.3 : 0.1),
                                        radius: 8,
                                        x: 0,
                                        y: 2
                                    )
                            }
                    }
            } else if cardType == .compactCardSmall {
                wiiUCard
            } else {
                normalGrid
            }
        }
    }
    
    
    @ViewBuilder
    var normalGrid: some View {
        VStack(spacing: 8) {
            // Game Icon
            ZStack {
                if let icon = game.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        .frame(width: 150, height: 150)
                    
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.titleName)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(game.developer)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(12)
        .frame(width: 174, height: 220)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: Color(.darkGray).opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
