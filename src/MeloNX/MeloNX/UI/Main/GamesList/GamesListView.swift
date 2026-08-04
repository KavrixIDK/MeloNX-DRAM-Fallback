//
//  GamesListView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import GameController
import Melo_Controller

enum ActiveSheet: Identifiable, Equatable{
    case gameInfo(game: GameInfo)
    case perGameSettings(game: GameInfo)
    // needs to be a full screen sheet so commented out
    // case gameController(game: Game)
    case dlc(game: GameInfo)
    case update(game: GameInfo)
    case mods(game: GameInfo)
    case account

    var id: String {
        switch self {
        case .gameInfo(let game),
             .perGameSettings(let game),
             // .gameController(let game),
             .dlc(let game),
             .mods(let game),
             .update(let game):
            return "\(type(of: self))-\(game.id)"
        case .account:
            return "account"
        }
    }
}



func bindingGame(_ game: Binding<GameInfo?>) -> Binding<Bool> {
    Binding(
        get: { game.wrappedValue != nil },
        set: { newValue in
            if !newValue {
                game.wrappedValue = nil
            }
        }
    )
}

extension UTType {
    static let nsp = UTType(exportedAs: "com.nintendo.switch-package")
    static let xci = UTType(exportedAs: "com.nintendo.switch-cartridge")
}

struct GamesListView: View {
    @EnvironmentObject public var ryujinxController: RyujinxController
    @StateObject var nativeSettings = NativeSettingsManager.shared
    @State var showingAccounts = false
    @State var activeSheet: ActiveSheet?
    @State var controllerEditor: GameInfo?
    @State var scrollTo: GameInfo?
    
    @State var previousDpadHandlers: [GCController: GCControllerDirectionPadValueChangedHandler?] = [:]
    @State var previousButtonAHandlers: [GCController: GCControllerButtonValueChangedHandler?] = [:]
    
    // Theme
    @Environment(\.appTheme) var theme
    
    var controllerEdit: Binding<Bool> {
        bindingGame($controllerEditor)
    }
    
    var games: Binding<[GameInfo]> {
        Binding(
            get: { ryujinxController.games },
            set: { ryujinxController.games = $0 }
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                ScrollViewReader { proxy in
                    Group {
                        if ryujinxController.games.isEmpty {
                            emptyStateView
                        } else if nativeSettings.cardLayout(CardType.card).value != .list {
                            var columns: [GridItem] {
                                switch nativeSettings.cardLayout(CardType.card).value {
                                case .card, .compactCard: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
                                case .compactCardNoBackground: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)]
                                case .compactCardSmall: [GridItem(.adaptive(minimum: 105, maximum: 120), spacing: 16)]
                                default: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
                                }
                            }
                            
                            
                            LazyVGrid(columns: columns, spacing: columns.first?.spacing ?? 16) {
                                ForEach(ryujinxController.games) { game in
                                    GameCardView(game: game)
                                        .id(game)
                                        .contextMenu {
                                            gameContextMenu(for: game)
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        } else {
                            ForEach(ryujinxController.games) { game in
                                Section {
                                    GameRowView(game: game)
                                        .id(game)
                                        .padding(.horizontal)
                                        .padding(.vertical, 5)
                                        .contextMenu {
                                            gameContextMenu(for: game)
                                        }
                                }
                            }
                            .onAppear() {
                                setupControllerObservers(scrollProxy: proxy)
                            }
                        }
                    }
                }
                
                if nativeSettings.disableLiquidGlass.value, UIDevice.current.userInterfaceIdiom == .phone {
                    Spacer().frame(height: AlertHandlers.topWindow().bounds.height / 10)
                }
            }
            .modifier(HiddenScrollBackground())
            .themedBackground()
            .overlay {
                if ryujinxController.isJITEnabled {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .frame(width: 12, height: 12)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(checkAppEntitlement("com.apple.developer.kernel.increased-memory-limit") ? Color.green : Color.orange)
                                .padding()
                        }
                        Spacer()
                    }
                    .offset(x: 0, y: -25)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                toolbarHandler()
            }
            .accentColor(theme.accent.primary)
            .fullScreenCover(isPresented: controllerEdit) {
                ControllerView(controller: VirtualControllerManager.shared, isEditing: true, gameId: controllerEditor?.titleId ?? "")
                    .interactiveDismissDisabled(true)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .gameInfo(let game):
                    GameInfoSheet(game: game)
                case .perGameSettings(let game):
                    PerGameSettingsView(game.titleId)
                case .dlc(let game):
                    DLCManagerSheet(game: game)
                case .update(let game):
                    UpdateManagerSheet(game: game)
                case .mods(let game):
                    ModsManagerSheet(game: game)
                case .account:
                    AccountManagerView()
                }
            }
        }
        .onAppear() {
            
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if #available(iOS 17, *) {
                ContentUnavailableView(
                    "No Games Found",
                    systemImage: "square.and.arrow.down",
                    description: Text("Tap the + button to add legally dumped ROMs!")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Games Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap the + button to add legally dumped ROMs!")
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
    
    
    private func gameContextMenu(for game: GameInfo) -> some View {
        Group {
            Section {
                Button {
                    ryujinxController.startGame(game)
                } label: {
                    Label("Play Now", systemImage: "play.fill")
                }
                
                Button {
                    activeSheet = .gameInfo(game: game)
                } label: {
                    Label("Game Info", systemImage: "info.circle")
                }
                
                Button {
                    activeSheet = .perGameSettings(game: game)
                } label: {
                    Label("\(game.titleName) Settings", systemImage: ryujinxController.perSettings[game.titleId] == nil ? "gear" : "checkmark.circle")
                }
                
                Button {
                    controllerEditor = game
                } label: {
                    Label("Controller Layout", systemImage: "formfitting.gamecontroller")
                }
            }
            
            Section {
                Button {
                    activeSheet = .update(game: game)
                } label: {
                    Label("Update Manager", systemImage: "arrow.up.circle")
                }
                
                Button {
                    activeSheet = .dlc(game: game)
                } label: {
                    Label("DLC Manager", systemImage: "plus.circle")
                }
                
                Button {
                    activeSheet = .mods(game: game)
                } label: {
                    Label("Mod Manager", systemImage: "folder.circle")
                }
            }
            
            Section {
                
                Button(role: .destructive) {
                    ryujinxController.clearShaderCache(game.titleId)
                } label: {
                    Label("Clear Shader Cache", systemImage: "trash")
                }
                
                Button(role: .destructive) {
                    deleteGame(game: game)
                } label: {
                    Label("Delete Game", systemImage: "trash")
                }
            }
        }
    }
    
    private func setupControllerObservers(scrollProxy: ScrollViewProxy) {
        if !GCController.controllers().isEmpty {
            if scrollTo == nil {
                scrollTo = ryujinxController.games.first
            }
        }
        
        let dpadHandler: GCControllerDirectionPadValueChangedHandler = { _, _, yValue in
            guard !ryujinxController.games.isEmpty else { return }
            
            guard let scrollTo, let index = ryujinxController.games.firstIndex(of: scrollTo) else { return }
            let newIndex = yValue == 1.0 ? max(0, index - 1) : yValue == -1.0 ? min(ryujinxController.games.count - 1, index + 1) : index
            let game = ryujinxController.games[newIndex]
            
            self.scrollTo = game
            scrollProxy.scrollTo(game)
        }
        
        for controller in GCController.controllers() {
            controller.playerIndex = .index1
            
            previousDpadHandlers[controller] = controller.extendedGamepad?.dpad.valueChangedHandler
            previousButtonAHandlers[controller] = controller.extendedGamepad?.buttonA.pressedChangedHandler
            
            controller.microGamepad?.dpad.valueChangedHandler = dpadHandler
            controller.extendedGamepad?.dpad.valueChangedHandler = dpadHandler
            
            controller.extendedGamepad?.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed {
                    Task { @MainActor in
                        if let scrollTo {
                            ryujinxController.startGame(scrollTo)
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            setupControllerObservers(scrollProxy: scrollProxy)
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { notif in
            if let controller = notif.object as? GCController {
                previousDpadHandlers.removeValue(forKey: controller)
            }
            if GCController.controllers().isEmpty {
                scrollTo = nil
            }
        }
    }
    
    private func deleteGame(game: GameInfo) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: game.fileURL)
            
        } catch {
        }
    }
}

struct ClearListBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct HiddenScrollBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
                .background(ClearListBackground())
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
        }
    }
}
