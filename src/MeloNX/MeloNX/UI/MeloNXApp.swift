//
//  MeloNXApp.swift
//  MeloNX
//
//  Created by Stossy11 on 4/4/2026.
//

import SwiftUI
import SDL3
import AVFoundation

func configureAudioSession() {
    Task.detached {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                options: .mixWithOthers
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
}

var environment: [EnvironmentVariable] = [
    EnvironmentVariable(string: "MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE", value: "128"),
]


func initEnvironmentVariables() {
    // Real physical RAM of this device, in MiB. Read once here (not gated by iOS version,
    // unlike HAS_TXM/DUAL_MAPPED_JIT below) so the C# side (Ryujinx.Memory.DeviceMemoryInfo)
    // can shrink otherwise-fixed reservations (JIT cache, AddressSpacePartitionAllocator's
    // 4GB blocks, AutoDeleteCache's texture budget) on low-RAM devices like the iPad 9th
    // generation (3 GB), which has no way to get the Extended Virtual Addressing entitlement
    // without a paid developer account or TrollStore, and therefore a very small usable
    // virtual address space ceiling. Devices that DO have plenty of RAM see no change, since
    // every consumer of this value only reacts below its own low-RAM threshold.
    let physicalMemoryMB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
    environment.append(
        EnvironmentVariable(string: "MELONX_DEVICE_RAM_MB", value: String(physicalMemoryMB))
    )

    if let device = MTLCreateSystemDefaultDevice(), device.argumentBuffersSupport.rawValue >= MTLArgumentBuffersTier.tier2.rawValue {
        environment.append(contentsOf: [
            .init(string: "MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", value: "0")
        ])
    }
    
    if #available(iOS 19, *) {
        environment.append(contentsOf: [
            .init(string: "HAS_TXM", value: ProcessInfo.processInfo.hasTXM && !ProcessInfo.processInfo.isiOSAppOnMac ? "1" : "0"),
            .init(string: "DUAL_MAPPED_JIT", value: "1")
        ])
    }
    
    for env in environment { env.set() }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}


@main
struct MeloNXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var ryujinxController: RyujinxController = .shared
    @StateObject var themeManager: ThemeManager = .shared
    
    @AppStorage("hasSetupFinished") var hasSetupFinished: Bool = false
    @AppStorage("lastAppversion") var lastAppversion: Data = Data()
    
    init() {
        SDL_SetMainReady()
        SDL_SetiOSEventPump(true)
        configureAudioSession()
        SDL_Init(SDL_INIT_EVENTS | SDL_INIT_AUDIO)
        configureAudioSession()
        JIT26BreakpointHandler()
        initEnvironmentVariables()
        Ryujinx.initialize()
        ThemeManager.shared.applyUIKitAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ryujinxController)
                .environmentObject(themeManager)
                .withAppTheme()
                .onAppear() {
                    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                    
                    let versionNumber = lastAppversion.withUnsafeBytes { $0.load(as: Float.self) }

                    
                    if versionNumber < Float(Bundle.main.versionNumber) ?? .zero {
                        lastAppversion = encodeFloatToData(Float(Bundle.main.versionNumber) ?? .zero)
                         hasSetupFinished = false
                    }
                }
                .sheet(isPresented: .constant(!hasSetupFinished)) {
                    SetupView {
                        hasSetupFinished = true
                        ryujinxController.loadGames()
                    }
                    .interactiveDismissDisabled()
                    .withAppTheme()
                }
        }
    }
    
    func encodeFloatToData(_ value: Float) -> Data {
        var mutableValue = value
        return Data(bytes: &mutableValue, count: MemoryLayout<Float>.size)
    }
}
