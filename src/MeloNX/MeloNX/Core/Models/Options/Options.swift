//
//  Options.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//


import Foundation

struct Options {

    // General
    var baseDataDir: String?
    var userProfile: String?
    var displayId: Int32 = 0
    var isFullscreen: Bool = false
    var isExclusiveFullscreen: Bool = false
    var exclusiveFullscreenWidth: Int32 = 1920
    var exclusiveFullscreenHeight: Int32 = 1080
    
    // Device Information
    var deviceModel: String?
    var memoryEnt: Bool = false
    var displayName: String?
    
    // Input
    var onScreenCorrespond: Bool = false
    
    var inputProfile1Name: String?
    var inputProfile2Name: String?
    var inputProfile3Name: String?
    var inputProfile4Name: String?
    var inputProfile5Name: String?
    var inputProfile6Name: String?
    var inputProfile7Name: String?
    var inputProfile8Name: String?
    var inputProfileHandheldName: String?
    
    var controllerType1: ControllerType = .proController
    var controllerType2: ControllerType = .proController
    var controllerType3: ControllerType = .proController
    var controllerType4: ControllerType = .proController
    var controllerType5: ControllerType = .proController
    var controllerType6: ControllerType = .proController
    var controllerType7: ControllerType = .proController
    var controllerType8: ControllerType = .proController
    
    var inputId1: String?
    var inputId2: String?
    var inputId3: String?
    var inputId4: String?
    var inputId5: String?
    var inputId6: String?
    var inputId7: String?
    var inputId8: String?
    var inputIdHandheld: String?
    
    var inputDSUServer1: String?
    var inputDSUServer2: String?
    var inputDSUServer3: String?
    var inputDSUServer4: String?
    var inputDSUServer5: String?
    var inputDSUServer6: String?
    var inputDSUServer7: String?
    var inputDSUServer8: String?
    var inputDSUServerHandheld: String?
    
    var enableKeyboard: Bool = false
    var enableMouse: Bool = false
    var hideCursorMode: HideCursorMode = .onIdle
    var listInputProfiles: Bool = false
    var listInputIds: Bool = false
    
    // System
    var disablePTC: Bool = false
    var enableInternetAccess: Bool = false
    var disableFsIntegrityChecks: Bool = false
    var fsGlobalAccessLogMode: Int32 = 0
    var disableVSync: Bool = false
    var disableShaderCache: Bool = true
    var enableTextureRecompression: Bool = false
    var disableDockedMode: Bool = true
    var systemLanguage: SystemLanguage = .americanEnglish
    var systemRegion: NativeRegionCode = .init(swiftRegionCode: Locale.current.regionCode) ?? .USA
    var systemTimeZone: String = TimeZone.current.identifier
    var systemTimeOffset: Int64 = 0
    var memoryManagerMode: MemoryManagerMode = .hostMappedUnsafe
    var audioVolume: Float = 1.0
    var useHypervisor: Bool = false
    var ldnMitm: Bool = false
    var multiplayerLanInterfaceId: String = "0"
    
    // Logging
    var disableFileLog: Bool = false
    var loggingEnableDebug: Bool = false
    var loggingDisableStub: Bool = false
    var loggingDisableInfo: Bool = false
    var loggingDisableWarning: Bool = false
    var loggingEnableError: Bool = false
    var loggingEnableTrace: Bool = false
    var loggingDisableGuest: Bool = false
    var loggingEnableFsAccessLog: Bool = false
    var loggingGraphicsDebugLevel: GraphicsDebugLevel = .none
    
    // Graphics
    var resScale: Float = 1.0
    var maxAnisotropy: Float = -1.0
    var aspectRatio: AspectRatio = .fixed16x9
    var backendThreading: BackendThreading = .off
    var enableAsyncShaderCompilation: Bool = false
    var disableMacroHLE: Bool = false
    var graphicsShadersDumpPath: String?
    var graphicsBackend: GraphicsBackend = .vulkan
    var preferredGPUVendor: String = ""
    var antiAliasing: AntiAliasing = .none
    var scalingFilter: ScalingFilter = .bilinear
    var scalingFilterLevel: Int32 = 60
    
    // Hacks
    var expandRAM: Bool = false
    var ignoreMissingServices: Bool = false
    
    // Value
    var inputPath: String
    
    init(inputPath: String) {
        self.inputPath = inputPath
    }
    
    func controllerType(for index: Int) -> ControllerType? {
        switch index {
        case 1: return controllerType1
        case 2: return controllerType2
        case 3: return controllerType3
        case 4: return controllerType4
        case 5: return controllerType5
        case 6: return controllerType6
        case 7: return controllerType7
        case 8: return controllerType8
        default: return nil
        }
    }
    
    
    func toNative() -> UnsafeMutablePointer<OptionsNative> {
        let n = UnsafeMutablePointer<OptionsNative>.allocate(capacity: 1)
        n.initialize(to: OptionsNative())
        
        func utf8(_ s: String?) -> UnsafeMutablePointer<CChar>? {
            guard let s else { return nil }
            return strdup(s)
        }
        
        n.pointee.BaseDataDir               = utf8(baseDataDir)
        n.pointee.UserProfile               = utf8(userProfile)
        n.pointee.DisplayId                 = displayId
        n.pointee.IsFullscreen              = isFullscreen
        n.pointee.IsExclusiveFullscreen     = isExclusiveFullscreen
        n.pointee.ExclusiveFullscreenWidth  = exclusiveFullscreenWidth
        n.pointee.ExclusiveFullscreenHeight = exclusiveFullscreenHeight
        
        n.pointee.DeviceModel  = utf8(deviceModel)
        n.pointee.MemoryEnt    = memoryEnt
        n.pointee.DisplayName  = utf8(displayName)
        
        n.pointee.OnScreenCorrespond       = onScreenCorrespond
        n.pointee.InputProfile1Name        = utf8(inputProfile1Name)
        n.pointee.InputProfile2Name        = utf8(inputProfile2Name)
        n.pointee.InputProfile3Name        = utf8(inputProfile3Name)
        n.pointee.InputProfile4Name        = utf8(inputProfile4Name)
        n.pointee.InputProfile5Name        = utf8(inputProfile5Name)
        n.pointee.InputProfile6Name        = utf8(inputProfile6Name)
        n.pointee.InputProfile7Name        = utf8(inputProfile7Name)
        n.pointee.InputProfile8Name        = utf8(inputProfile8Name)
        n.pointee.InputProfileHandheldName = utf8(inputProfileHandheldName)
        
        n.pointee.ControllerType1 = controllerType1
        n.pointee.ControllerType2 = controllerType2
        n.pointee.ControllerType3 = controllerType3
        n.pointee.ControllerType4 = controllerType4
        n.pointee.ControllerType5 = controllerType5
        n.pointee.ControllerType6 = controllerType6
        n.pointee.ControllerType7 = controllerType7
        n.pointee.ControllerType8 = controllerType8
        
        n.pointee.InputId1        = utf8(inputId1)
        n.pointee.InputId2        = utf8(inputId2)
        n.pointee.InputId3        = utf8(inputId3)
        n.pointee.InputId4        = utf8(inputId4)
        n.pointee.InputId5        = utf8(inputId5)
        n.pointee.InputId6        = utf8(inputId6)
        n.pointee.InputId7        = utf8(inputId7)
        n.pointee.InputId8        = utf8(inputId8)
        n.pointee.InputIdHandheld = utf8(inputIdHandheld)
        
        n.pointee.InputDSUServer1        = utf8(inputDSUServer1)
        n.pointee.InputDSUServer2        = utf8(inputDSUServer2)
        n.pointee.InputDSUServer3        = utf8(inputDSUServer3)
        n.pointee.InputDSUServer4        = utf8(inputDSUServer4)
        n.pointee.InputDSUServer5        = utf8(inputDSUServer5)
        n.pointee.InputDSUServer6        = utf8(inputDSUServer6)
        n.pointee.InputDSUServer7        = utf8(inputDSUServer7)
        n.pointee.InputDSUServer8        = utf8(inputDSUServer8)
        n.pointee.InputDSUServerHandheld = utf8(inputDSUServerHandheld)
        
        n.pointee.EnableKeyboard    = enableKeyboard
        n.pointee.EnableMouse       = enableMouse
        n.pointee.HideCursorMode    = hideCursorMode
        n.pointee.ListInputProfiles = listInputProfiles
        n.pointee.ListInputIds      = listInputIds
        
        n.pointee.DisablePTC                 = disablePTC
        n.pointee.EnableInternetAccess       = enableInternetAccess
        n.pointee.DisableFsIntegrityChecks   = disableFsIntegrityChecks
        n.pointee.FsGlobalAccessLogMode      = fsGlobalAccessLogMode
        n.pointee.DisableVSync               = disableVSync
        n.pointee.DisableShaderCache         = disableShaderCache
        n.pointee.EnableTextureRecompression = enableTextureRecompression
        n.pointee.DisableDockedMode          = disableDockedMode
        n.pointee.SystemLanguage             = systemLanguage
        n.pointee.SystemRegion               = systemRegion
        n.pointee.SystemTimeZone             = utf8(systemTimeZone)
        n.pointee.SystemTimeOffset           = systemTimeOffset
        n.pointee.MemoryManagerMode          = memoryManagerMode
        n.pointee.AudioVolume                = audioVolume
        n.pointee.UseHypervisor              = useHypervisor
        n.pointee.LdnMitm                    = ldnMitm
        n.pointee.MultiplayerLanInterfaceId  = utf8(multiplayerLanInterfaceId)
        
        n.pointee.DisableFileLog            = disableFileLog
        n.pointee.LoggingEnableDebug        = loggingEnableDebug
        n.pointee.LoggingDisableStub        = loggingDisableStub
        n.pointee.LoggingDisableInfo        = loggingDisableInfo
        n.pointee.LoggingDisableWarning     = loggingDisableWarning
        n.pointee.LoggingEnableError        = loggingEnableError
        n.pointee.LoggingEnableTrace        = loggingEnableTrace
        n.pointee.LoggingDisableGuest       = loggingDisableGuest
        n.pointee.LoggingEnableFsAccessLog  = loggingEnableFsAccessLog
        n.pointee.LoggingGraphicsDebugLevel = loggingGraphicsDebugLevel
        
        n.pointee.ResScale                = resScale
        n.pointee.MaxAnisotropy           = maxAnisotropy
        n.pointee.AspectRatio             = aspectRatio
        n.pointee.BackendThreading        = backendThreading
        n.pointee.EnableAsyncShaderCompilation = enableAsyncShaderCompilation
        n.pointee.DisableMacroHLE         = disableMacroHLE
        n.pointee.GraphicsShadersDumpPath = utf8(graphicsShadersDumpPath)
        n.pointee.GraphicsBackend         = graphicsBackend
        n.pointee.PreferredGPUVendor      = utf8(preferredGPUVendor)
        n.pointee.AntiAliasing            = antiAliasing
        n.pointee.ScalingFilter           = scalingFilter
        n.pointee.ScalingFilterLevel      = scalingFilterLevel
        
        n.pointee.ExpandRAM             = expandRAM
        n.pointee.IgnoreMissingServices = ignoreMissingServices
        
        n.pointee.InputPath = utf8(inputPath)
        
        return n
    }
    
    static func freeOptionsNative(_ n: UnsafeMutablePointer<OptionsNative>) {
        free(n.pointee.BaseDataDir)
        free(n.pointee.UserProfile)
        free(n.pointee.DeviceModel)
        free(n.pointee.DisplayName)
        free(n.pointee.InputProfile1Name)
        free(n.pointee.InputProfile2Name)
        free(n.pointee.InputProfile3Name)
        free(n.pointee.InputProfile4Name)
        free(n.pointee.InputProfile5Name)
        free(n.pointee.InputProfile6Name)
        free(n.pointee.InputProfile7Name)
        free(n.pointee.InputProfile8Name)
        free(n.pointee.InputProfileHandheldName)
        free(n.pointee.InputId1)
        free(n.pointee.InputId2)
        free(n.pointee.InputId3)
        free(n.pointee.InputId4)
        free(n.pointee.InputId5)
        free(n.pointee.InputId6)
        free(n.pointee.InputId7)
        free(n.pointee.InputId8)
        free(n.pointee.InputIdHandheld)
        free(n.pointee.InputDSUServer1)
        free(n.pointee.InputDSUServer2)
        free(n.pointee.InputDSUServer3)
        free(n.pointee.InputDSUServer4)
        free(n.pointee.InputDSUServer5)
        free(n.pointee.InputDSUServer6)
        free(n.pointee.InputDSUServer7)
        free(n.pointee.InputDSUServer8)
        free(n.pointee.InputDSUServerHandheld)
        free(n.pointee.SystemTimeZone)
        free(n.pointee.MultiplayerLanInterfaceId)
        free(n.pointee.GraphicsShadersDumpPath)
        free(n.pointee.PreferredGPUVendor)
        free(n.pointee.InputPath)
        
        n.deallocate()
    }
}
