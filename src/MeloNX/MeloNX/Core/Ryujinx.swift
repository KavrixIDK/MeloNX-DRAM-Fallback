//
//  Ryujinx.swift
//  MeloNX
//
//  Created by Stossy11 on 13/4/2026.
//

import MetalKit

enum FirmwareInstallationError: Error {
    case failedInstall(String)
}

final class Ryujinx {
    static var emulationView: MTKView?
    
    static func initialize() {
        MeloNX.initialize()
    }
    
    static func stopEmulation() {
        MeloNX.stop_emulation()
    }
    
    static func mainRyu(_ native: Options) -> Int {
        return Int(MeloNX.main_ryujinx_sdl(native.toNative()))
    }
    
    static func setNativeWindow(_ layerPtr: UnsafeMutableRawPointer) {
        MeloNX.set_native_window(layerPtr)
    }
    
    static func getGameInfo(arg0: Int32, arg1: NSString, path: URL) -> GameInfo {
        let arg1Ptr = UnsafeMutablePointer<CChar>(mutating: arg1.utf8String)
        return GameInfo(MeloNX.get_game_info(arg0, arg1Ptr), url: path)
    }
    
    static func attachGamepad(_ id: UnsafeMutableRawPointer?, _ name: String, _ index: Int, _ type: ControllerType) {
        _ = name.withCString { MeloNX.attach_gamepad($0, id, Int32(index), type)  }
    }
    
    static func detachGamepad(_ id: UnsafeMutableRawPointer?) {
        MeloNX.detach_gamepad(id)
    }

    static func setGamepadButtonState(_ id: UnsafeMutableRawPointer?, buttonId: Int, pressed: Bool) {
        MeloNX.set_gamepad_button_state(id, Int32(buttonId), pressed ? 1 : 0)
    }

    static func setGamepadStickAxis(_ id: UnsafeMutableRawPointer?, stickId: Int, x: Float, y: Float) {
        MeloNX.set_gamepad_stick_axis(id, Int32(stickId), x, y)
    }
    
    static func setGamepadMotion(_ id: UnsafeMutableRawPointer?, motionType: Int, axis: SIMD3<Float>) {
        MeloNX.set_gamepad_motion_axis(id, Int32(motionType), axis.x, axis.y, axis.z)
    }

    static func initDualMapping() -> Bool {
        MeloNX.init_dualmapping()
    }
    
    static func reloadKeySet() {
        MeloNX.load_keyset()
    }
    
    static var installedFirmwareVersion: String {
        let firmware = MeloNX.installed_firmware_version()
        defer { MeloNX.free_firmware_version(firmware) }
        return String(cString: firmware)
    }
    
    static func installFirmware(at path: String) throws {
        let error = path.withCString {
            MeloNX.install_firmware($0)
        }
        
        guard let error else { return }
        
        let string = String(cString: error)
        defer { MeloNX.free_firmware_version(error) }

        throw FirmwareInstallationError.failedInstall(string)
    }
    
    static func touchBegan(_ point: CGPoint, index: Int) {
        MeloNX.touch_began(Float(point.x), Float(point.y), Int32(index))
    }
    
    static func touchEnded(index: Int) {
        MeloNX.touch_ended(Int32(index))
    }
    
    static func touchMoved(_ point: CGPoint, index: Int) {
        MeloNX.touch_moved(Float(point.x), Float(point.y), Int32(index))
    }
    
    static func setViewSize(_ rect: CGRect) {
        MeloNX.set_view_size(Int32(rect.width), Int32(rect.height))
    }

    static func setUnboundedPresentTargetFps(for screen: UIScreen?) {
        let targetFps = max(1, screen?.maximumFramesPerSecond ?? Air.shared.airScreen?.maximumFramesPerSecond ?? UIScreen.main.maximumFramesPerSecond)
        set_unbounded_present_target_fps(Int32(targetFps))
    }
    
    private static func getDlcList(titleId: String, path: String) -> DlcNcaListC {
        titleId.withCString { titlePtr in
            path.withCString { pathPtr in
                return MeloNX.get_dlc_nca_list(titlePtr, pathPtr)
            }
        }
    }
    
    static func getDlcNcaList(titleId: String, path: String) -> [DownloadableContentNca] {
        let listPointer = Self.getDlcList(titleId: titleId, path: path)
        defer { MeloNX.free_dlc_nca_list(listPointer) }
        guard listPointer.success, listPointer.size > 0, let items = listPointer.items else { return [] }

        let list = Array(UnsafeBufferPointer(start: items, count: Int(listPointer.size)))

        return list.map { item in
                .init(fullPath: withUnsafePointer(to: item.Path) {
                    $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                        String(cString: $0)
                    }
                }, titleId: item.TitleId, enabled: true)
        }
    }
    
    static var defaultKeyboard: KeyboardConfigNative {
        .init(LeftJoycon:
                .init(DpadUp: Key_Up, DpadDown: Key_Down, DpadLeft: Key_Left, DpadRight: Key_Right, ButtonMinus: Key_Minus, ButtonL: Key_E, ButtonZl: Key_Q, ButtonSl: Key_Unbound, ButtonSr: Key_Unbound),
              LeftJoyconStick:
                .init(StickUp: Key_W, StickDown: Key_S, StickLeft: Key_A, StickRight: Key_D, StickButton: Key_F),
              RightJoycon:
                .init(ButtonA: Key_Z, ButtonB: Key_X, ButtonX: Key_C, ButtonY: Key_V, ButtonPlus: Key_Plus, ButtonR: Key_U, ButtonZr: Key_O, ButtonSl: Key_Unbound, ButtonSr: Key_Unbound),
              RightJoyconStick:
                .init(StickUp: Key_I, StickDown: Key_K, StickLeft: Key_J, StickRight: Key_L, StickButton: Key_H))
    }
    
    static func setKeyboardConfig(_ config: KeyboardConfigNative) {
        set_keyboard_config(config)
    }
    
    static func refreshAccountManager() {
        refresh_account_manager()
    }
    
    static func createAccount(name: String, image: Data) {
        name.withCString { namePtr in
            image.withUnsafeBytes { bufferpointer in
                let imagePtr = bufferpointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                create_account(namePtr, imagePtr, Int32(image.count))
            }
        }
    }
    

    static func openUser(userId: String) {
        userId.withCString { open_user($0) }
    }

    static func closeUser(userId: String) {
        userId.withCString { close_user($0) }
    }
    
    static var avatars: AvatarArrayC {
        get_avatars()
    }
    
    static func getFirmwareIcons() -> [Avatar] {
        let avatarArray = self.avatars
        let count = Int(avatarArray.Count)
        var result: [Avatar] = []
        
        guard let avatarsPtr = avatarArray.Avatars else {
            return []
        }

        for i in 0..<count {
            let avatar = avatarsPtr.advanced(by: i).pointee
            
            if let imageDataPtr = avatar.ImageData {
                let imageSize = Int(avatar.ImageSize)
                let image = imageFromRawRGBA(Data(bytes: imageDataPtr, count: imageSize))
                
                let filename = avatar.FileName != nil ? String(cString: avatar.FileName!) : ""
                
                
                result.append(Avatar(icon: image ?? UIImage(), name: filename))
            }
        }
        
        return result
    }
    
    private static func imageFromRawRGBA(_ data: Data, width: Int = 256, height: Int = 256) -> UIImage? {
        guard data.count == width * height * 4 else {
            return nil
        }

        let cfData = data as CFData
        guard let provider = CGDataProvider(data: cfData) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.last.rawValue | // RGBA (not premultiplied)
            CGBitmapInfo.byteOrder32Big.rawValue // Make sure it's big endian RGBA
        )

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
    
    static func togglePauseEmulation(_ pause: Bool) {
        toggle_pause_emulation(pause)
    }

    /*
    static func initialize_dualmapped() -> Bool {
        MeloNX.initialize_dualmapped()
    }


    static func getDlcList(titleId: String, path: String) -> DlcNcaList {
        titleId.withCString { titlePtr in
            path.withCString { pathPtr in
                return MeloNX.get_dlc_nca_list(titlePtr, pathPtr)
            }
        }
    }

    static func installFirmware(at path: String) -> (string: String, isError: Bool) {
        guard let firmware = (path.withCString { MeloNX.install_firmware($0) }) else { return ("Failed to get error.", true) }
        var string = String(cString: firmware)
        let isErr = string.hasSuffix("✖")
        string.removeLast()
        defer { MeloNX.free_firmware_version(firmware) }
        return (string, isErr)
    }

    static var installedFirmwareVersion: String {
        guard let firmware = MeloNX.installed_firmware_version() else { return "" }
        defer { MeloNX.free_firmware_version(firmware) }
        return String(cString: firmware)
    }

    static func pauseEmulation(_ shouldPause: Bool) {
        MeloNX.pause_emulation(shouldPause)
    }

    static func stopEmulation() {
        MeloNX.stop_emulation()
    }

    static func mainRyu(argv: [String]) -> Int {
        return argv.withCStrings { cStrings, argc in
            Int(MeloNX.main_ryujinx_sdl(argc, cStrings))
        }
    }
    
    static func changeControllerInfo(argv: [String]) {
        argv.withCStrings { cStrings, argc in
            MeloNX.set_gamepad_configuration(argc, cStrings)
        }
    }

    static func updateSettingsExternal(argv: [String]) -> Int {
        return argv.withCStrings { cStrings, argc in
            Int(MeloNX.update_settings_external(argc, cStrings))
        }
    }
    
    static func setViewSize(width: Int, height: Int) {
        MeloNX.set_view_size(Int32(width), Int32(height))
    }

    static var currentFPS: Int {
        Int(MeloNX.get_current_fps())
    }
    
    static var currentVolume: Float {
        get {
            MeloNX.get_game_volume()
        } set {
            MeloNX.set_game_volume(newValue)
        }
    }


    static func touchBegan(x: Float, y: Float, index: Int) {
        MeloNX.touch_began(x, y, Int32(index))
    }

    static func touchMoved(x: Float, y: Float, index: Int) {
        MeloNX.touch_moved(x, y, Int32(index))
    }

    static func touchEnded(index: Int) {
        MeloNX.touch_ended(Int32(index))
    }

    static func refreshAccountManager() {
        MeloNX.refresh_account_manager()
    }

    static func createAccount(name: String, image: Data) {
        name.withCString { namePtr in
            image.withUnsafeBytes { bufferpointer in
                let imagePtr = bufferpointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                MeloNX.create_account(namePtr, imagePtr, Int32(image.count))
            }
        }
    }

    static func openUser(userId: String) {
        userId.withCString { MeloNX.open_user($0) }
    }

    static func closeUser(userId: String) {
        userId.withCString { MeloNX.close_user($0) }
    }
    
    static func attachGamepad(_ id: UnsafeMutableRawPointer?, _ name: String) {
        _ = name.withCString { MeloNX.attach_gamepad($0, id)  }
    }
    
    static func detachGamepad(_ id: UnsafeMutableRawPointer?) {
        MeloNX.detach_gamepad(id)
    }

    static func setGamepadButtonState(_ id: UnsafeMutableRawPointer?, buttonId: Int, pressed: Bool) {
        print("Gamepad button State \(Int32(buttonId)), pressed \(pressed)")
        MeloNX.set_gamepad_button_state(id, Int32(buttonId), pressed ? 1 : 0)
    }

    static func setGamepadStickAxis(_ id: UnsafeMutableRawPointer?, stickId: Int, x: Float, y: Float) {
        MeloNX.set_gamepad_stick_axis(id, Int32(stickId), x, y)
    }
    
    static func setGamepadMotion(_ id: UnsafeMutableRawPointer?, motionType: Int, axis: SIMD3<Float>) {
        MeloNX.set_gamepad_motion_axis(id, Int32(motionType), axis.x, axis.y, axis.z)
    }

    static var avatars: AvatarArray {
        MeloNX.get_avatars()
    }
     */
}

fileprivate extension Array where Element == String {
    func withCStrings<R>(_ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, Int32) -> R) -> R {
        var cStrings = map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        return cStrings.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else {
                fatalError("Failed to get baseAddress")
            }
            return body(base, Int32(count))
        }
    }
}

extension UIImage {
    func jpgData(compressionQuality: CGFloat = 1.0) -> Data? {
        return self.jpegData(compressionQuality: compressionQuality)
    }
}



@_silgen_name("set_native_window")
fileprivate func set_native_window(_ layerPtr: UnsafeMutableRawPointer!)

@_silgen_name("main_ryujinx_sdl")
fileprivate func main_ryujinx_sdl(_ options: UnsafeMutablePointer<OptionsNative>) -> Int32

@_silgen_name("set_keyboard_config")
fileprivate func set_keyboard_config(_ options: KeyboardConfigNative)

@_silgen_name("initialize")
fileprivate func initialize()

@_silgen_name("stop_emulation")
fileprivate func stop_emulation()

@_silgen_name("load_keyset")
fileprivate func load_keyset()

@_silgen_name("installed_firmware_version")
fileprivate func installed_firmware_version() -> UnsafePointer<CChar>

@_silgen_name("free_firmware_version")
fileprivate func free_firmware_version(_ versionPtr: UnsafePointer<CChar>)

@_silgen_name("install_firmware")
fileprivate func install_firmware(_ pathPtr: UnsafePointer<CChar>) -> UnsafePointer<CChar>?

@_silgen_name("init_dualmapping")
fileprivate func init_dualmapping() -> Bool

@_silgen_name("get_game_info")
fileprivate func get_game_info(_ arg0: Int32, _ arg1: UnsafeMutablePointer<CChar>!) -> GameInfoC

@_silgen_name("free_game_info")
func free_game_info(_ gameInfo: GameInfoC)

@_silgen_name("attach_gamepad")
fileprivate func attach_gamepad(_ namePtr: UnsafePointer<CChar>?, _ idPtr: UnsafeMutableRawPointer?, _ playerIndex: Int32, _ controllerType: ControllerType) -> UnsafeMutableRawPointer?

@_silgen_name("detach_gamepad")
fileprivate func detach_gamepad(_ idPtr: UnsafeMutableRawPointer?)

@_silgen_name("set_gamepad_button_state")
fileprivate func set_gamepad_button_state(_ idPtr: UnsafeMutableRawPointer?, _ buttonId: Int32, _ pressed: UInt8)

@_silgen_name("set_gamepad_stick_axis")
fileprivate func set_gamepad_stick_axis(_ idPtr: UnsafeMutableRawPointer?, _ stickId: Int32, _ x: Float, _ y: Float)

@_silgen_name("set_gamepad_motion_axis")
fileprivate func set_gamepad_motion_axis(_ idPtr: UnsafeMutableRawPointer?, _ motionType: Int32, _ x: Float, _ y: Float, _ z: Float)

@_silgen_name("touch_began")
fileprivate func touch_began(_ x: Float, _ y: Float, _ index: Int32)

@_silgen_name("touch_moved")
fileprivate func touch_moved(_ x: Float, _ y: Float, _ index: Int32)

@_silgen_name("touch_ended")
fileprivate func touch_ended(_ index: Int32)

@_silgen_name("set_view_size")
fileprivate func set_view_size(_ width: Int32, _ height: Int32)

@_silgen_name("set_unbounded_present_target_fps")
fileprivate func set_unbounded_present_target_fps(_ targetFps: Int32)

@_silgen_name("get_dlc_nca_list")
func get_dlc_nca_list(_ titleIdPtr: UnsafePointer<CChar>!, _ pathPtr: UnsafePointer<CChar>!) -> DlcNcaListC

@_silgen_name("free_dlc_nca_list")
fileprivate func free_dlc_nca_list(_ list: DlcNcaListC)

@_silgen_name("get_avatars")
fileprivate func get_avatars() -> AvatarArrayC

@_silgen_name("refresh_account_manager")
fileprivate func refresh_account_manager()

@_silgen_name("create_account")
fileprivate func create_account(_ name: UnsafePointer<CChar>!, _ image: UnsafePointer<UInt8>!, _ imagelength: Int32)

@_silgen_name("open_user")
fileprivate func open_user(_ userid: UnsafePointer<CChar>!)

@_silgen_name("close_user")
fileprivate func close_user(_ userid: UnsafePointer<CChar>!)

@_silgen_name("toggle_pause_emulation")
fileprivate func toggle_pause_emulation(_ shouldPause: Bool)


// installed_firmware_version
