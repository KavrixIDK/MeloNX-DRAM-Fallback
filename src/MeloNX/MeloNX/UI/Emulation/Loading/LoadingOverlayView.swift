//
//  LoadingOverlayView.swift
//  MeloNX
//
//  Created by Stossy11 on 07/11/2025.
//

import SwiftUI
import Combine

class LoadingOverlayViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isAnimating = false
    @Published var isShaderOrPTC = false
    @Published var loadingType = ""
    @Published var currentProgress = 0
    @Published var totalProgress = 1

    
    func setupLoading() {
        let userData = Unmanaged.passRetained(self).toOpaque()
        
        RegisterCallback("ProgressWithPTCorShaderCache", { rawPtr, userData in
            guard let userData else { return }
            let vm = Unmanaged<LoadingOverlayViewModel>.fromOpaque(userData).takeUnretainedValue()
            
            guard let rawPtr else {
                Task { @MainActor in vm.isShaderOrPTC = false }
                print("ptr nil")
                return
            }
            
            let callbackData = rawPtr.load(as: CallbackData.self)
            
            guard callbackData.len > 0, let ptr = callbackData.ptr else {
                Task { @MainActor in vm.isShaderOrPTC = false }
                print("len no workie")
                return
            }
            
            let rawData = Data(bytes: ptr, count: Int(callbackData.len))
            
            guard let jsonArray = try? JSONSerialization.jsonObject(with: rawData) as? [Any],
                  jsonArray.count == 3,
                  let type = jsonArray[0] as? String,
                  let current = jsonArray[1] as? Int,
                  let total = jsonArray[2] as? Int else {
                print("No JSON")
                Task { @MainActor in vm.isShaderOrPTC = false }
                return
            }
            
            Task {
                await MainActor.run {
                    if current < total - 10 {
                        vm.isShaderOrPTC = true
                        vm.loadingType = type
                        vm.currentProgress = current
                        vm.totalProgress = total
                    } else {
                        vm.isShaderOrPTC = false
                    }
                }
            }
        }, userData)
    }
}

struct LoadingOverlayView: View {
    let game: GameInfo?
    let showLogs: Bool
    
    @StateObject private var vm = LoadingOverlayViewModel()
    @State private var contentVisible = false
    
    private let clumpWidth: CGFloat = 80
    
    var body: some View {
        if vm.isLoading {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                    loadingContent(geo: geo)
                }
            }
            .opacity(contentVisible ? 1 : 0)
            .onAppear {
                vm.setupLoading()
                vm.isAnimating = true
                withAnimation(.easeIn(duration: 0.3)) {
                    contentVisible = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func loadingContent(geo: GeometryProxy) -> some View {
        HStack(spacing: geo.size.width * 0.04) {
            if let icon = game?.icon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: min(geo.size.width * 0.22, 220),
                        height: min(geo.size.width * 0.22, 220)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 12)
            }
            
            VStack(alignment: .leading, spacing: geo.size.height * 0.018) {
                Text("Loading \(game?.titleName ?? "Game")")
                    .font(.system(
                        size: min(geo.size.width * 0.038, 28),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white)
                
                LoadingProgressBar(
                    screenGeometry: geo,
                    isAnimating: $vm.isAnimating,
                    isShaderOrPTC: $vm.isShaderOrPTC,
                    currentProgress: $vm.currentProgress,
                    totalProgress: $vm.totalProgress,
                    clumpWidth: clumpWidth
                )
                
                if vm.isShaderOrPTC {
                    progressLabel(geo: geo)
                }
            }
        }
        .padding(.horizontal, geo.size.width * 0.06)
        .padding(.vertical, geo.size.height * 0.05)
        .position(
            x: geo.size.width / 2,
            y: geo.size.height / 2
        )
    }
    
    private func progressLabel(geo: GeometryProxy) -> some View {
        HStack(spacing: 4) {
            Text(vm.loadingType + ": ")
                .fontWeight(.medium)
            Text("\(vm.currentProgress)")
                .monospacedDigit()
            Text("/")
                .opacity(0.5)
            Text("\(vm.totalProgress)")
                .monospacedDigit()
        }
        .font(.system(size: min(geo.size.width * 0.025, 13)))
        .foregroundStyle(.white.opacity(0.55))
    }
}
