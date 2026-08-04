//
//  JITPopover.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct NoJITView: View {
    var game: GameInfo
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ryujinxController: RyujinxController
    @ObservedObject public var nativeSettingsManager = NativeSettingsManager.shared
    
    @State private var isJIT: Bool = false
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let icon = game.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        }
                } else {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("Waiting for JIT")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Waiting for Just-In-Time compilation...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                    
                    Text("JIT compilation enables MeloNX to achieve maximum performance by dynamically translating and executing code on the fly.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    
                    Text("Enabling JIT is required for the emulator to function.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
            )
            
            
            Button("Go Back") {
                ryujinxController.lastGameLaunched = nil
                ryujinxController.isRunning = .stopped
            }
            .foregroundStyle(Color.accentColor)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
            )
        }
        .padding(24)
        .frame(maxWidth: 400)
        .onAppear {
            pulseAnimation = true
            
            EnableJIT.enableJIT(nativeSettingsManager.jitProvider(JITProvider.disabled).value)
            
            Task.detached {
                while !jitEnabled() {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        ryujinxController.startGame(game)
                    }
                }
            }
        }
    }
}
