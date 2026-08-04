//
//  ContentView.swift
//  MeloNX
//
//  Created by Stossy11 on 4/4/2026.
//

import SwiftUI
import MetalKit
import Melo_Controller

struct EnvironmentVariable: Codable, Hashable {
    let string: String
    var value: String
    
    func set() {
        setenv(string, value, 1)
    }
    
    static func set(_ env: EnvironmentVariable) {
        setenv(env.string, env.value, 1)
    }
}



struct ContentView: View {
    @EnvironmentObject var ryujinxController: RyujinxController
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject public var nativeSettingsManager = NativeSettingsManager.shared
    @StateObject var controllerManager: ControllerManager = .shared
    @State private var selectedTab: Tab = .games
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.appTheme) var theme
    
    var tabView: some View {
        TabView(selection: $selectedTab) {
            GamesListView()
                .tabItem { Label("Library", systemImage: "gamecontroller.fill") }
                .tag(Tab.games)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        .accentColor(theme.accent.primary)
        .onOpenURL(perform: { AppEnvironment.handleDeepLink($0, ryujinxController: ryujinxController) } )
        .onAppear { NativeSettingsManager.setShared() }
        .task {
            EnableJIT.enableJIT(nativeSettingsManager.jitProvider(JITProvider.disabled).value)
            
            _ = ryujinxController.attemptToMapDualMapping()
            
            ryujinxController.loadGames()
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            controllerManager.initAll()
            
            MetalViewRepresentable.createView()
            
            AlertHandlers.register()
            
            Air.play(AnyView(Text("Select Game")))
        }
    }
    
    @ViewBuilder
    func emulationView(game: GameInfo, state: StartedState) -> some View {
        switch state {
        case .none:
            EmulationView()
        case .entitlement:
            ControllerView(controller: VirtualControllerManager.shared, isEditing: false)
                .allowsHitTesting(false)
                .frame(width: .infinity, height: .infinity)
                .alert(isPresented: .constant(ryujinxController.isRunning.isEntitlement())) {
                    Alert(
                        title: Text("Entitlement"),
                        message: Text(LocalizedStringKey("MeloNX **REQUIRES** the Increased Memory Limit entitlement, Please follow the instructions on how to Install MeloNX and Enable the Entitlement.")),
                        primaryButton: .default(Text("Instructions")) {
                            UIApplication.shared.open(
                                URL(string: "https://git.ryujinx.app/melonx/emu#how-to-install")!,
                                options: [:],
                                completionHandler: nil
                            )
                            ryujinxController.isRunning = .stopped
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            ryujinxController.isRunning = .stopped
                        }
                    )
                }
        case .noJIT:
            NoJITView(game: game)
        case .usersList:
            EmptyView() // TODO: Finish by 2.4.1 or 2.5
        }
    }
    
    var body: some View {
        Group {
            switch ryujinxController.isRunning {
            case .stopped:
                tabView
            case .started(game: let game, state: let state):
                emulationView(game: game, state: state)
            case .crashed(result: _):
                tabView
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                if ryujinxController.isRunning.isRunning() {
                    if !ryujinxController.wasManuallyPaused {
                        ryujinxController.isPaused = false
                    }
                } else {
                    _ = ryujinxController.attemptToMapDualMapping()
                }
            case .inactive:
                if ryujinxController.isRunning.isRunning(), !ryujinxController.wasManuallyPaused {
                    ryujinxController.isPaused = true
                }
                break
            case .background:
                if ryujinxController.isRunning.isRunning(), !ryujinxController.wasManuallyPaused {
                    ryujinxController.isPaused = true
                }
                break
            @unknown default:
                break
            }
        }
    }
}





#Preview {
    ContentView()
}
