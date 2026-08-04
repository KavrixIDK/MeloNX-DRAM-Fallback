//
//  SettingsView.swift
//  MeloNX
//
//  Created by Stossy11 on 23/4/2026.
//

import SwiftUI
import UIKit
import Melo_Controller
import UniformTypeIdentifiers
import NavigationStackBackport

struct SettingsView: View {
    @EnvironmentObject var ryujinxController: RyujinxController
    @ObservedObject public var nativeSettingsManager = NativeSettingsManager.shared
    @ObservedObject var controllerManager = ControllerManager.shared
    let appEnvironment: AppEnvironment = .shared
    
    @AppStorage("useTrollStore") var useTrollStore: Bool = false
    @AppStorage("OldView") var oldView = true
    @AppStorage("LDN_MITM") var ldn = printAllIPv4Addresses().first ?? "Unknown"
    @AppStorage("hasSetupFinished") var hasSetupFinished: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.appTheme) var theme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    
    @State private var selectedCategory: SettingsCategory = .graphics
    @State private var isShowingGameController = false
    @State private var showOSIcon = true
    @State private var showingAppIconSwitcher = false
    @State private var showingThemePicker = false
    @State private var showingKeyboardConfig = false
    @FocusState private var isArgumentsKeyboardVisible: Bool
    
    
    private var config: Binding<Options> {
        $ryujinxController.settings
    }
    
    var currentResolution: String {
        let base: Int = config.wrappedValue.disableDockedMode ? 720 : 1080
        let val = Float(base) * config.wrappedValue.resScale
        return val.toOneDecimalString() + "p"
    }
    
    private let memoryManagerModes: [(MemoryManagerMode, String)] = [
        (.hostMapped, "Host (fast)"),
        (.hostMappedUnsafe, "Host Unchecked (fast, unstable / unsafe)"),
        (.softwarePageTable, "Software (slow)"),
    ]
    
    private let totalMemory = ProcessInfo.processInfo.physicalMemory
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var isRegularLayout: Bool {
        (horizontalSizeClass == .regular && verticalSizeClass == .regular) ||
        (horizontalSizeClass == .regular && verticalSizeClass == .compact)
    }
    
    private var deviceIcon: String {
        let model = UIDevice.modelName
        if model.contains("iPad") { return "ipad" }
        if model.contains("iPhone") { return "iphone" }
        return "desktopcomputer"
    }
    
    private var memoryText: String {
        let divisor = ProcessInfo.processInfo.isiOSAppOnMac ? (1024 * 1024 * 1024) : 1_000_000_000
        return String(format: "%.0f GB", Double(totalMemory) / Double(divisor))
    }
    
    private var systemVersionString: String {
        let versionPart = ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")
        let parts = versionPart.components(separatedBy: " (Build ")
        let osName = ProcessInfo.processInfo.isiOSAppOnMac ? "macOS" : UIDevice.current.systemName
        if parts.count == 2 {
            let build = parts[1].replacingOccurrences(of: ")", with: "")
            return "\(osName) \(parts[0]) (\(build))"
        }
        return "\(osName) \(UIDevice.current.systemVersion)"
    }
    
    private var osVersionString: String {
        let osName = ProcessInfo.processInfo.isiOSAppOnMac
        ? "macOS"
        : UIDevice.current.systemName
        
        return "\(osName) \(UIDevice.current.systemVersion)"
    }
    
    enum SettingsCategory: LocalizedStringKey, CaseIterable, Identifiable {
        case graphics = "Graphics"
        case input    = "Input"
        case misc     = "Misc"
        case system   = "System"
        case advanced = "Advanced"
        
        var id: String { "\(rawValue)" }
        
        var icon: String {
            switch self {
            case .graphics: return "paintbrush.fill"
            case .input:    return "gamecontroller.fill"
            case .system:   return "gearshape.fill"
            case .misc:     return "ellipsis.circle.fill"
            case .advanced: return "terminal.fill"
            }
        }
        
        @ViewBuilder
        func formView(for parent: SettingsView) -> some View {
            switch self {
            case .graphics: parent.graphicsForm
            case .input:    parent.inputForm
            case .misc:     parent.miscForm
            case .system:   parent.systemForm
            case .advanced: parent.advancedForm
            }
        }
    }
    
    var isPortrait: Bool {
        AlertHandlers.topWindow().bounds.height > AlertHandlers.topWindow().bounds.width
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone  {
                iOSSettings
            } else {
                iPadSettings
            }
        }
        .onDisappear { ryujinxController.saveConfig() }
    }
    
    // MARK: - iPhone
    
    var iOSSettings: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    
                    HStack(spacing: 6) {
                        jitRow
                    }
                    .padding(.horizontal, 16)
                    
                    let infoColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

                    LazyVGrid(columns: infoColumns, spacing: 6) {
                        Label(UIDevice.modelName, systemImage: deviceIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { showOSIcon.toggle() }
                        } label: {
                            Group {
                                if isPortrait {
                                    if showOSIcon {
                                        Label(osVersionString, systemImage: "applelogo")
                                            .font(.caption)
                                    } else {
                                        Text(systemVersionString)
                                            .font(.system(size: 9))
                                    }
                                } else {
                                    Label(systemVersionString, systemImage: "applelogo")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        if !ProcessInfo.processInfo.isiOSAppOnMac {
                            let memoryLimit = checkAppEntitlement("com.apple.developer.kernel.increased-memory-limit")
                            Menu {
                                Button {
                                    if !memoryLimit {
                                        UIApplication.shared.open(URL(string: "https://git.ryujinx.app/projects/MeloNX#entitlements")!)
                                    }
                                } label: {
                                    Text("Increased Memory Limit: \(memoryLimit ? "Enabled" : "Disabled")")
                                }
                            } label: {
                                Label(title: {
                                    memoryLimit ? Text(memoryText + "  ") + Text(Image(systemName: "checkmark.circle.fill")).foregroundColor(.green) : Text(memoryText)
                                }, icon: {
                                    Image(systemName: "memorychip.fill")
                                })
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(Color(.tertiarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(SettingsCategory.allCases) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedCategory = category
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(category.rawValue)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                                .background(
                                    selectedCategory == category
                                    ? theme.accent.secondary
                                    : Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .foregroundStyle(
                                    selectedCategory == category ? Color.white : Color.primary
                                )
                                .animation(.easeInOut(duration: 0.18), value: selectedCategory)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                
                Divider()
                
                selectedCategory.formView(for: self)
                    .id(selectedCategory.id)
                
            }
            .if(isPortrait) {
                $0
                    .navigationTitle("Settings")
            }
            .themedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadSettings)
        }
    }
    
    var selectedCategoryOp: Binding<SettingsCategory?> {
        .init {
            selectedCategory
        } set: { set in
            selectedCategory = set ?? .system
        }
        
    }
    
    // MARK: - iPad
    
    var iPadSettings: some View {
        NavigationView {
            List {
                Section {
                    jitRow
                    deviceInfoCards
                }
                
                Section("Settings") {
                    ForEach(SettingsCategory.allCases) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        } label: {
                            Label(category.rawValue, systemImage: category.icon)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundColor(category.id == selectedCategory.id ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(category.id == selectedCategory.id ? theme.accent.secondary : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            
            selectedCategory.formView(for: self)
                .navigationTitle(Text(selectedCategory.rawValue))
                .modifier(HiddenScrollBackground())
                .themedBackground()
        }
        .onAppear(perform: loadSettings)
    }
    
    private var jitRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ryujinxController.isJITEnabled ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            if ProcessInfo.processInfo.isiOSAppOnMac && !checkAppEntitlement("get-task-allow") {
                Text("JIT Enabled (macOS)")
                    .foregroundColor(ryujinxController.isJITEnabled ? .green : .red)
            } else if !checkAppEntitlement("get-task-allow") &&
                        !checkAppEntitlement("com.apple.security.cs.allow-jit") &&
                        !checkAppEntitlement("dynamic-codesigning") &&
                        !ryujinxController.isJITEnabled {
                Text("No JIT Support")
                    .foregroundColor(.red)
            } else {
                Text(ryujinxController.isJITEnabled ? "JIT Enabled" : "JIT Not Acquired")
                    .foregroundColor(ryujinxController.isJITEnabled ? .green : .red)
            }
            
            Spacer()
            
            Spacer()
            Text("v\(appVersion)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .font(.subheadline.weight(.medium))
    }
    
    @ViewBuilder
    private var deviceInfoCards: some View {
        VStack(spacing: 16) {
            InfoCard(
                title: "Device",
                value: "\(UIDevice.modelName)",
                icon: deviceIcon,
                color: .blue
            )
            
            InfoCard(
                title: "System",
                value: "\(systemVersionString)",
                icon: "applelogo",
                color: .gray
            )
            
            if ProcessInfo.processInfo.isiOSAppOnMac {
                InfoCard(
                    title: "Increased Memory Limit",
                    value: "Not needed (macOS)",
                    icon: "memorychip.fill",
                    color: .orange
                )
            } else {
                let memoryLimit = checkAppEntitlement("com.apple.developer.kernel.increased-memory-limit")
                Button {
                    if !memoryLimit {
                        UIApplication.shared.open(URL(string: "https://git.ryujinx.app/projects/MeloNX#entitlements")!)
                    }
                } label: {
                    InfoCard(
                        title: "Increased Memory Limit",
                        value: memoryLimit ? "Enabled" : "Disabled",
                        icon: "memorychip.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
                if checkAppEntitlement("com.apple.developer.kernel.extended-virtual-addressing") {
                    InfoCard(
                        title: "Extended Virtual Addressing",
                        value: "Enabled",
                        icon: "memorychip",
                        color: .yellow
                    )
                }
                if let lc = appEnvironment.lcBundle, appEnvironment.isInLiveContainer, !appEnvironment.isInMultitask {
                    InfoCard(
                        title: "LiveContainer",
                        value: "v\(lc.infoDictionary?["CFBundleShortVersionString"] as? String ?? (lc.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")) \(lc.infoDictionary?["LCVersionInfo"] as? String ?? "")",
                        icon: "app.fill",
                        color: .indigo
                    )
                } else if appEnvironment.isInMultitask {
                    InfoCard(
                        title: "LiveContainer",
                        value: "Multitask",
                        icon: "app.fill",
                        color: .indigo
                    )
                }
            }
        }
    }
    
    // MARK: - Graphics Form
    
    var graphicsForm: some View {
        Form {
            // Resolution Scale
            Section {
                if nativeSettingsManager.allowCustomResValue.value {
                    let formatter: NumberFormatter = {
                        let f = NumberFormatter(); f.numberStyle = .decimal; return f
                    }()
                    HStack {
                        Text("Resolution Scale")
                        Spacer()
                        TextField("Scale", value: config.resScale, formatter: formatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } else {
                    SliderRow(
                        "Resolution Scale",
                        value: config.resScale,
                        range: 0.1...4.0,
                        step: 0.05,
                        minLabel: "0.1x",
                        maxLabel: "4.0x",
                        extended: "(\(currentResolution))"
                    )
                }
            } header: {
                HStack {
                    Text("Resolution")
                    Spacer()
                    InfoButton(
                        title: "Resolution Scale",
                        message: "Adjust the internal rendering resolution. Higher values improve visuals but may reduce performance. Lowering is unsupported for some games and may cause crashing."
                    )
                }
            } footer: {
                if nativeSettingsManager.allowCustomResValue.value {
                    Text("Custom scale mode enabled via long-press.")
                }
            }
            .contextMenu {
                Button {
                    nativeSettingsManager.allowCustomResValue.value = !(nativeSettingsManager.allowCustomResValue.value as Bool)
                } label: {
                    Label(
                        nativeSettingsManager.allowCustomResValue.value
                        ? "Disable Custom Resolution Scale"
                        : "Allow Any Resolution Scale",
                        systemImage: nativeSettingsManager.allowCustomResValue.value ? "checkmark" : "slider.horizontal.3"
                    )
                }
            }
            
            // Anisotropic Filtering
            Section {
                SliderRow(
                    "Max Anisotropic Filtering",
                    value: config.maxAnisotropy,
                    range: 0...16.0,
                    step: 0.1,
                    minLabel: "Off",
                    maxLabel: "16x",
                    format: "%.1f"
                )
            } header: {
                HStack {
                    Text("Filtering")
                    Spacer()
                    InfoButton(
                        title: "Max Anisotropic Filtering",
                        message: "Adjust the internal anisotropic filtering. Higher values improve texture quality at angles. Default (0) lets the game decide."
                    )
                }
            }
            
            Section("Scaling Options") {
                Picker("Scaling Filter", selection: config.scalingFilter) {
                    ForEach(ScalingFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                
                if config.wrappedValue.scalingFilter == .fsr {
                    let levelBinding = Binding<Float>(
                        get: { Float(config.wrappedValue.scalingFilterLevel) },
                        set: { config.wrappedValue.scalingFilterLevel = Int32($0) }
                    )
                    
                    SliderRow(
                        "Filter Sharpness",
                        value: levelBinding,
                        range: 0...100.0,
                        step: 1.0,
                        minLabel: "0%",
                        maxLabel: "100%",
                        format: "%.0f"
                    )
                }
            }
            
            // Display Toggles
            Section("Display") {
                NativeToggleRow("Shader Cache", icon: "memorychip",
                                isOn: config.disableShaderCache.reversed,
                                info: "Shader Cache saves shaders to a file and preloads them on game launch. Leave OFF if unsure.")
                
                NativeToggleRow("VSync", icon: "arrow.triangle.2.circlepath",
                                isOn: config.disableVSync.reversed,
                                info: "VSync makes the game run at the Switch's framerate. Disabling may cause games to run at screen refresh rate, affecting speed. Leave ON if unsure.")
                NativeToggleRow("Docked Mode", icon: "dock.rectangle",
                                isOn: config.disableDockedMode.reversed,
                                info: "Docked mode emulates a docked Nintendo Switch, improving graphics. Disabling emulates handheld mode. Leave OFF if unsure.")
                NativeToggleRow("Macro HLE", icon: "gearshape",
                                isOn: config.disableMacroHLE.reversed,
                                info: "High-level emulation of GPU Macro code. Improves performance but may cause graphical glitches. Leave OFF if unsure.")
                
                NativeToggleRow("Async Shader Compilation (EXPERIMENTAL)", icon: "bolt.horizontal.circle",
                                isOn: config.enableAsyncShaderCompilation,
                                info: "Compiles Vulkan shader pipelines in the background to reduce stalls. Newly seen effects may appear after compilation finishes. May break graphics or cause crashes in some games.")
                .tint(.red)
                .foregroundStyle(.red)
            }
            
            // Performance Overlay
            Section("Performance Overlay") {
                NativeToggleRow("Performance Overlay", icon: "speedometer",
                                isOn: nativeSettingsManager.performacehud.projectedValue,
                                info: "Shows framerate, frametime, memory usage, fifo (First In, First Out) and battery info while a game is running.")
                
                if nativeSettingsManager.performacehud.value {
                    NativeToggleRow("Show Battery Percentage", icon: "battery.100percent.bolt",
                                    isOn: nativeSettingsManager.showBatteryPercentage.projectedValue)
                    
                    NativeToggleRow("Show Frame Time", icon: "clock.arrow.2.circlepath",
                                    isOn: nativeSettingsManager.performanceFrameTime(true).projectedValue)
                    
                    NativeToggleRow("Show Memory Usage", icon: "memorychip",
                                    isOn: nativeSettingsManager.performanceRam(true).projectedValue)
                    
                    NativeToggleRow("Show FIFO", icon: "arrow.left.arrow.right",
                                    isOn: nativeSettingsManager.performanceFIFO.projectedValue)
                    
                    NativeToggleRow("Horizontal Layout", icon: "rotate.right",
                                    isOn: nativeSettingsManager.horizontalorvertical.projectedValue,
                                    info: "Changes the Performance Overlay to display horizontally instead of vertically.")
                    
                    NativeToggleRow("Move Overlay below Screen", icon: "arrow.uturn.down",
                                    isOn: nativeSettingsManager.overlayBelowScreen(true).projectedValue,
                                    info: "When device is in portrait, the overlay will be moved below the game screen.")
                    
                }
                
                Picker("Overlay Position", selection: nativeSettingsManager.performancePosition(PerformanceOverlayPosition.topRight).projectedValue) {
                    ForEach(PerformanceOverlayPosition.allCases, id: \.self) { position in
                        Text(position.displayValue).tag(position)
                    }
                }
            }
            
            // Aspect Ratio
            Section("Aspect Ratio") {
                Picker("Aspect Ratio", selection: config.aspectRatio) {
                    ForEach(AspectRatio.allCases, id: \.self) { ratio in
                        Text(ratio.displayName).tag(ratio)
                    }
                }
            }
        }
    }
    
    var inputForm: some View {
        Form {
            Section("Controller Selection") {
                if controllerManager.selectedControllers.isEmpty {
                    Text("No controllers selected, keyboard will be used")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(controllerManager.selectedControllers.enumerated()), id: \.offset) { index, id in
                        ControllerRow(index: index, controllerId: id, controllerManager: controllerManager)
                    }
                }
                if hasAvailableControllers {
                    Menu {
                        ForEach(controllerManager.allControllers.filter {
                            !contains(controllerManager.selectedControllers, value: $0)
                        }) { controller in
                            Button(controller.name) {
                                controllerManager.selectedControllers.append(controller.id)
                            }
                        }
                    } label: {
                        Label("Add Controller", systemImage: "plus.circle.fill")
                    }
                }
            }
            
            if controllerManager.selectedControllers.isEmpty {
                Section {
                    Button("Map Keyboard") {
                        showingKeyboardConfig = true
                    }
                    .sheet(isPresented: $showingKeyboardConfig) {
                        KeyboardConfigView()
                    }
                }
            }
            
            // Button mapping
            Section {
                NativeToggleRow(
                    "Swap Face Buttons (Physical Controller)",
                    icon: "rectangle.2.swap",
                    isOn: nativeSettingsManager.swapBandA.projectedValue,
                    info: "Swaps A ↔ B and X ↔ Y on ALL physical controllers. To swap only one controller, use the Settings app."
                )
            } header: {
                Text("Button Mapping")
            }
            
            // On-Screen Controller
            Section("On-Screen Controller") {
                Button {
                    isShowingGameController = true
                } label: {
                    Label("Edit Layout", systemImage: "formfitting.gamecontroller")
                }
                .fullScreenCover(isPresented: $isShowingGameController) {
                    ControllerView(controller: VirtualControllerManager.shared, isEditing: true, gameId: nil)
                }
                
                SliderRow(
                    "Scale",
                    value: nativeSettingsManager.setting(forKey: "On-ScreenControllerScale", default: 1.0).projectedValue,
                    range: 0.1...3.0,
                    step: 0.05,
                    minLabel: "Smaller",
                    maxLabel: "Larger"
                )
                
                SliderRow(
                    "Opacity",
                    value: nativeSettingsManager.setting(forKey: "On-ScreenControllerOpacity", default: 1.0).projectedValue,
                    range: 0.05...1.0,
                    step: 0.05,
                    minLabel: "More Transparent",
                    maxLabel: "Less Transparent"
                )
                
                NativeToggleRow("Show Stick Buttons (L3/R3)", icon: "l.joystick.press.down",
                                isOn: nativeSettingsManager.stickButton.projectedValue,
                                info: "Shows L3 and R3 buttons (left and right joystick press) on the virtual controller.")
                NativeToggleRow("Deselected by Default", icon: "formfitting.gamecontroller.fill",
                                isOn: nativeSettingsManager.virtualControllerOffDefault(ProcessInfo.processInfo.isiOSAppOnMac).projectedValue,
                                info: "Deselects the virtual controller by default, regardless of whether a physical controller is connected.")
            }
        }
    }
    
    
    // MARK: - System Form
    
    var systemForm: some View {
        Form {
            Section("Language & Region") {
                Picker("System Language", selection: config.systemLanguage) {
                    ForEach(Array(SystemLanguage.allCases), id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                
                Picker("Region", selection: config.systemRegion) {
                    ForEach(Array(NativeRegionCode.allCases), id: \.self) { region in
                        Text(region.displayName).tag(region)
                    }
                }
            }
            
            Section {
                Picker("Memory Manager Mode", selection: config.memoryManagerMode) {
                    ForEach(memoryManagerModes, id: \.0.rawValue) { mode, name in
                        Text(name).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("CPU Configuration")
            }
        }
    }
    
    var advancedForm: some View {
        Form {
            Section("Debug Logging") {
                NativeToggleRow("Debug Logs", icon: "exclamationmark.bubble",
                                isOn: config.loggingEnableDebug,
                                info: "Prints debug log messages. Only enable if asked by a staff member — it degrades performance and makes logs harder to read.")
                NativeToggleRow("Trace Logs", icon: "waveform.path",
                                isOn: config.loggingEnableTrace,
                                info: "Prints trace log messages. Does not affect performance.")
                NativeToggleRow("Write Logs to stdout", icon: "hammer",
                                isOn: nativeSettingsManager.writeStdout.projectedValue,
                                info: "Write logs to stdout, disabling the default log file output.")
            }
            
            Section("Behaviour") {
                NativeToggleRow("Disable FS Integrity Checks", icon: "checkmark.shield",
                                isOn: config.disableFsIntegrityChecks,
                                info: "Checks for corrupt files when booting. Hash errors appear in the log if corruption is found. Leave OFF if unsure.")
                NativeToggleRow("Ignore JIT Popup", icon: "cpu",
                                isOn: nativeSettingsManager.ignoreJIT.projectedValue,
                                info: "Ignores the JIT popup and tries to load the game regardless.")
                
                Button("Show Setup Screen") {
                    hasSetupFinished = false
                }
                .foregroundColor(.accentColor)
            }
            
            Section {
                NativeToggleRow("Expand Guest RAM", icon: "memorychip.fill",
                                isOn: config.expandRAM,
                                info: "Uses an alternative memory mode with 8 GiB DRAM to mimic a Switch dev unit. Only useful for high-res texture packs or 4K mods. Does NOT improve performance. Leave OFF if unsure.")
                .disabled(5723 > totalMemory)
                NativeToggleRow("Ignore Missing Services", icon: "waveform.path",
                                isOn: config.ignoreMissingServices,
                                info: "Ignores unimplemented Horizon OS services. May help bypass crashes on certain games. Leave OFF if unsure.")
            } header: {
                Text("Memory")
            } footer: {
                if totalMemory < 5723 {
                    Text("Expand Guest RAM requires at least 6 GB of physical memory.")
                }
            }
            
            Section("System Info") {
                LabeledRow(label: "Page Size", value: String(Int(getpagesize())))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let bounds = scene.windows.first?.bounds {
                    LabeledRow(label: "App Resolution", value: "\(Int(bounds.width))×\(Int(bounds.height))")
                }
            }
            
            Section {
                HStack {
                    Text("In memoriam of 'Lily'")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                    Image(systemName: "heart")
                        .foregroundColor(.purple)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    
    // MARK: - Misc Form
    
    var miscForm: some View {
        Form {
            // Custom ROM Folders
            Section("Custom ROM Folders") {
                FolderListView()
            }
            
            // Network
            Section {
                Picker("Network Interface", selection: $ldn) {
                    ForEach(printAllIPv4Addresses(), id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                NativeToggleRow("Guest Internet Access / LAN Mode", icon: "wifi.router.fill",
                                isOn: config.enableInternetAccess,
                                info: "Allows the emulated app to connect to the Internet. LAN mode games can connect across devices on the same network, including real consoles. Does NOT connect to Nintendo servers. May cause crashes in some games. Leave OFF if unsure.")
                NativeToggleRow("ldn_mitm", icon: "ipad.sizes",
                                isOn: config.ldnMitm,
                                info: "Modifies local wireless to function as LAN, allowing same-network connections with other Ryujinx instances and hacked Switch consoles with ldn_mitm installed. All players must be on the same game version. Leave OFF if unsure.")
            } header: {
                Text("Network")
            }
            
            // UI Options
            Section("Interface") {
                Button {
                    showingThemePicker = true
                } label: {
                    HStack {
                        Label("Theme", systemImage: "paintpalette.fill")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(theme.accent.primary)
                                .frame(width: 12, height: 12)
                            Text(theme.name)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .sheet(isPresented: $showingThemePicker) {
                    ThemePickerView()
                }
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NativeToggleRow("Toggle Color Green when ON", icon: "arrow.clockwise",
                                    isOn: nativeSettingsManager.toggleGreen.projectedValue,
                                    info: "Makes all enabled options show in green.")
                }
                NativeToggleRow("Disable Touch", icon: "hand.point.up.left.fill",
                                isOn: nativeSettingsManager.disableTouch.projectedValue,
                                info: "Disables the touch screen (not the virtual controller).")
                
                Picker("Library View", selection: nativeSettingsManager.cardLayout(CardType.card).projectedValue) {
                    ForEach(CardType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                
                NativeToggleRow("Menu Button (in-game)", icon: "arrow.left.circle",
                                isOn: nativeSettingsManager.showScreenShotButton(true).projectedValue,
                                info: "Shows an in-game menu button to exit, lock orientation (iPhone only), change aspect ratio, or change controllers.")
                NativeToggleRow("Keep App in Background", icon: "location.viewfinder",
                                isOn: nativeSettingsManager.setting(forKey: "location-enabled", default: false).projectedValue,
                                info: "Uses Location to keep the app in the background. Does NOT track or store any data.")
                
                
                Button {
                    showingAppIconSwitcher = true
                } label: {
                    Text("App Icon Switcher")
                }
                .sheet(isPresented: $showingAppIconSwitcher) {
                    AppIconSwitcherView()
                }
                
            }
            
            // JIT and Updates
            Section("JIT & Updates") {
                HStack {
                    Text("JIT Enabler")
                    Spacer()
                    Picker("", selection: nativeSettingsManager.jitProvider(JITProvider.disabled).projectedValue) {
                        ForEach(JITProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                let model = UIDevice.modelName
                if !model.contains("Mac") || !ProcessInfo.processInfo.isiOSAppOnMac {
                    if #available(iOS 19, *) {
                        HStack {
                            Label("Dual Mapped JIT", systemImage: "light.strip.2")
                            Spacer()
                            Text("Always On (iOS 26)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        NativeToggleRow("Dual Mapped JIT", icon: "light.strip.2",
                                        isOn: nativeSettingsManager.setting(forKey: "DUAL_MAPPED_JIT", default: false).projectedValue,
                                        info: "iOS 26 / Non-TXM JIT.")
                        .disabled(ProcessInfo.processInfo.hasTXM)
                    }
                } else {
                    NativeToggleRow("Dual Mapped JIT", icon: "light.strip.2",
                                    isOn: nativeSettingsManager.setting(forKey: "DUAL_MAPPED_JIT", default: false).projectedValue)
                }
                
                NativeToggleRow("Check for Updates", icon: "square.and.arrow.down",
                                isOn: nativeSettingsManager.checkForUpdate(true).projectedValue,
                                info: "Automatically checks for updates on launch.")
                
            }
        }
    }
    
    private var hasAvailableControllers: Bool {
        !ControllerManager.shared.allControllers
            .filter { !contains(ControllerManager.shared.selectedControllers, value: $0) }
            .isEmpty
    }
    
    func contains(_ array: [String], value: BaseController) -> Bool {
        array.contains { $0 == value.id }
    }
    
    private func loadSettings() { ryujinxController.loadConfig() }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension Binding where Value == Bool {
    var reversed: Binding<Bool> {
        Binding(get: { !self.wrappedValue }, set: { self.wrappedValue = !$0 })
    }
}

extension View {
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

struct FolderListView: View {
    @StateObject private var folderManager = ROMFolderManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(folderManager.bookmarks, id: \.self) { path in
                HStack {
                    Label(
                        folderManager.getUrl(from: path)?.lastPathComponent ?? "Unknown",
                        systemImage: "folder.fill"
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        folderManager.bookmarks.removeAll(where: { $0 == path })
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            
            Button {
                FileImporterManager.shared.importFiles(types: [.folder]) { result in
                    if case .success(let paths) = result {
                        for url in paths {
                            let _ = folderManager.addFolder(url: url)
                        }
                    }
                }
            } label: {
                Label("Add Folder", systemImage: "plus.circle.fill")
            }
            .padding(.vertical, 4)
        }
    }
}


func printAllIPv4Addresses() -> [String] {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    var cool: [String] = []
    
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [] }
    
    var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while ptr != nil {
        let interface = ptr!.pointee
        let name = String(cString: interface.ifa_name)
        
        if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let address = String(cString: hostname)
                if !cool.contains(where: { $0.contains(address) }), address != "127.0.0.1" {
                    cool.append("\(name): \(address)")
                }
            }
        }
        ptr = interface.ifa_next
    }
    freeifaddrs(ifaddr)
    
    if let idx = cool.firstIndex(where: { $0.contains("en0") }), idx != 0 {
        let el = cool.remove(at: idx)
        cool.insert(el, at: 0)
    }
    return cool
}


struct NavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        if #available(iOS 16, *) {
            SwiftUI.NavigationStack(root: content)
        } else {
            NavigationStackBackport.NavigationStack(root: content)
        }
    }
}
extension Float {
    func toOneDecimalString() -> String {
        String(format: "%g", (self * 10).rounded() / 10)
    }
}
