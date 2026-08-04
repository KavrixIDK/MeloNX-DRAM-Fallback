//
//  Options+Codable.swift
//  MeloNX
//
//  Created by Stossy11 on 20/4/2026.
//

import UIKit
import Foundation

extension Options: Codable {
    enum CodingKeys: String, CodingKey {
        case controllerType1, controllerType2, controllerType3, controllerType4
        case controllerType5, controllerType6, controllerType7, controllerType8
        case hideCursorMode, listInputProfiles, listInputIds
        case disablePTC, enableInternetAccess, disableFsIntegrityChecks, fsGlobalAccessLogMode
        case disableVSync, vSyncMode, customVSyncInterval, disableShaderCache, enableTextureRecompression, disableDockedMode
        case systemLanguage, systemRegion, systemTimeZone, systemTimeOffset
        case memoryManagerMode, audioVolume, useHypervisor, ldnMitm, multiplayerLanInterfaceId
        case disableFileLog, loggingEnableDebug, loggingDisableStub, loggingDisableInfo
        case loggingDisableWarning, loggingEnableError, loggingEnableTrace, loggingDisableGuest
        case loggingEnableFsAccessLog, loggingGraphicsDebugLevel
        case resScale, maxAnisotropy, aspectRatio, backendThreading, enableAsyncShaderCompilation, disableMacroHLE
        case graphicsShadersDumpPath, graphicsBackend, preferredGPUVendor
        case antiAliasing, scalingFilter, scalingFilterLevel
        case expandRAM, ignoreMissingServices
        case inputPath
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        try c.encodeIfPresent(graphicsShadersDumpPath, forKey: .graphicsShadersDumpPath)
        
        try c.encode(controllerType1.rawValue,   forKey: .controllerType1)
        try c.encode(controllerType2.rawValue,   forKey: .controllerType2)
        try c.encode(controllerType3.rawValue,   forKey: .controllerType3)
        try c.encode(controllerType4.rawValue,   forKey: .controllerType4)
        try c.encode(controllerType5.rawValue,   forKey: .controllerType5)
        try c.encode(controllerType6.rawValue,   forKey: .controllerType6)
        try c.encode(controllerType7.rawValue,   forKey: .controllerType7)
        try c.encode(controllerType8.rawValue,   forKey: .controllerType8)
        try c.encode(hideCursorMode.rawValue,    forKey: .hideCursorMode)
        try c.encode(listInputProfiles,          forKey: .listInputProfiles)
        try c.encode(listInputIds,               forKey: .listInputIds)
        try c.encode(disablePTC,                 forKey: .disablePTC)
        try c.encode(enableInternetAccess,       forKey: .enableInternetAccess)
        try c.encode(disableFsIntegrityChecks,   forKey: .disableFsIntegrityChecks)
        try c.encode(fsGlobalAccessLogMode,      forKey: .fsGlobalAccessLogMode)
        try c.encode(disableVSync,               forKey: .disableVSync)
        try c.encode(vSyncMode.rawValue,         forKey: .vSyncMode)
        try c.encode(customVSyncInterval,        forKey: .customVSyncInterval)
        try c.encode(disableShaderCache,         forKey: .disableShaderCache)
        try c.encode(enableTextureRecompression, forKey: .enableTextureRecompression)
        try c.encode(disableDockedMode,          forKey: .disableDockedMode)
        try c.encode(systemLanguage.rawValue,    forKey: .systemLanguage)
        try c.encode(systemRegion.rawValue,      forKey: .systemRegion)
        try c.encode(systemTimeZone,             forKey: .systemTimeZone)
        try c.encode(systemTimeOffset,           forKey: .systemTimeOffset)
        try c.encode(memoryManagerMode.rawValue, forKey: .memoryManagerMode)
        try c.encode(audioVolume,                forKey: .audioVolume)
        try c.encode(useHypervisor,              forKey: .useHypervisor)
        try c.encode(ldnMitm,                    forKey: .ldnMitm)
        try c.encode(multiplayerLanInterfaceId,  forKey: .multiplayerLanInterfaceId)
        try c.encode(disableFileLog,             forKey: .disableFileLog)
        try c.encode(loggingEnableDebug,         forKey: .loggingEnableDebug)
        try c.encode(loggingDisableStub,         forKey: .loggingDisableStub)
        try c.encode(loggingDisableInfo,         forKey: .loggingDisableInfo)
        try c.encode(loggingDisableWarning,      forKey: .loggingDisableWarning)
        try c.encode(loggingEnableError,         forKey: .loggingEnableError)
        try c.encode(loggingEnableTrace,         forKey: .loggingEnableTrace)
        try c.encode(loggingDisableGuest,        forKey: .loggingDisableGuest)
        try c.encode(loggingEnableFsAccessLog,   forKey: .loggingEnableFsAccessLog)
        try c.encode(loggingGraphicsDebugLevel.rawValue, forKey: .loggingGraphicsDebugLevel)
        try c.encode(resScale,                   forKey: .resScale)
        try c.encode(maxAnisotropy,              forKey: .maxAnisotropy)
        try c.encode(aspectRatio.rawValue,       forKey: .aspectRatio)
        try c.encode(backendThreading.rawValue,  forKey: .backendThreading)
        try c.encode(enableAsyncShaderCompilation, forKey: .enableAsyncShaderCompilation)
        try c.encode(disableMacroHLE,            forKey: .disableMacroHLE)
        try c.encode(graphicsBackend.rawValue,   forKey: .graphicsBackend)
        try c.encode(preferredGPUVendor,         forKey: .preferredGPUVendor)
        try c.encode(antiAliasing.rawValue,      forKey: .antiAliasing)
        try c.encode(scalingFilter.rawValue,     forKey: .scalingFilter)
        try c.encode(scalingFilterLevel,         forKey: .scalingFilterLevel)
        try c.encode(expandRAM,                  forKey: .expandRAM)
        try c.encode(ignoreMissingServices,      forKey: .ignoreMissingServices)
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        inputPath = ""
        
        
        listInputProfiles          = try c.decodeIfPresent(Bool.self,   forKey: .listInputProfiles)        ?? false
        listInputIds               = try c.decodeIfPresent(Bool.self,   forKey: .listInputIds)             ?? false
        disablePTC                 = try c.decodeIfPresent(Bool.self,   forKey: .disablePTC)               ?? false
        enableInternetAccess       = try c.decodeIfPresent(Bool.self,   forKey: .enableInternetAccess)     ?? false
        disableFsIntegrityChecks   = try c.decodeIfPresent(Bool.self,   forKey: .disableFsIntegrityChecks) ?? false
        fsGlobalAccessLogMode      = try c.decodeIfPresent(Int32.self,  forKey: .fsGlobalAccessLogMode)    ?? 0
        disableVSync               = try c.decodeIfPresent(Bool.self,   forKey: .disableVSync)             ?? false
        vSyncMode                  = VSyncMode(rawValue: try c.decodeIfPresent(Int32.self, forKey: .vSyncMode) ?? (disableVSync ? VSyncMode.unbounded.rawValue : VSyncMode.switchMode.rawValue)) ?? .switchMode
        customVSyncInterval        = try c.decodeIfPresent(Int32.self,  forKey: .customVSyncInterval)      ?? 120
        disableShaderCache         = try c.decodeIfPresent(Bool.self,   forKey: .disableShaderCache)       ?? true
        enableTextureRecompression = try c.decodeIfPresent(Bool.self,   forKey: .enableTextureRecompression) ?? false
        disableDockedMode          = try c.decodeIfPresent(Bool.self,   forKey: .disableDockedMode)        ?? true
        systemTimeZone             = try c.decodeIfPresent(String.self, forKey: .systemTimeZone)           ?? "UTC"
        systemTimeOffset           = try c.decodeIfPresent(Int64.self,  forKey: .systemTimeOffset)         ?? 0
        audioVolume                = try c.decodeIfPresent(Float.self,  forKey: .audioVolume)              ?? 1.0
        useHypervisor              = try c.decodeIfPresent(Bool.self,   forKey: .useHypervisor)            ?? false
        ldnMitm                    = try c.decodeIfPresent(Bool.self,   forKey: .ldnMitm)                  ?? false
        multiplayerLanInterfaceId  = try c.decodeIfPresent(String.self, forKey: .multiplayerLanInterfaceId) ?? "0"
        disableFileLog             = try c.decodeIfPresent(Bool.self,   forKey: .disableFileLog)           ?? false
        loggingEnableDebug         = try c.decodeIfPresent(Bool.self,   forKey: .loggingEnableDebug)       ?? false
        loggingDisableStub         = try c.decodeIfPresent(Bool.self,   forKey: .loggingDisableStub)       ?? false
        loggingDisableInfo         = try c.decodeIfPresent(Bool.self,   forKey: .loggingDisableInfo)       ?? false
        loggingDisableWarning      = try c.decodeIfPresent(Bool.self,   forKey: .loggingDisableWarning)    ?? false
        loggingEnableError         = try c.decodeIfPresent(Bool.self,   forKey: .loggingEnableError)       ?? false
        loggingEnableTrace         = try c.decodeIfPresent(Bool.self,   forKey: .loggingEnableTrace)       ?? false
        loggingDisableGuest        = try c.decodeIfPresent(Bool.self,   forKey: .loggingDisableGuest)      ?? false
        loggingEnableFsAccessLog   = try c.decodeIfPresent(Bool.self,   forKey: .loggingEnableFsAccessLog) ?? false
        resScale                   = try c.decodeIfPresent(Float.self,  forKey: .resScale)                 ?? 1.0
        maxAnisotropy              = try c.decodeIfPresent(Float.self,  forKey: .maxAnisotropy)            ?? -1.0
        enableAsyncShaderCompilation = try c.decodeIfPresent(Bool.self, forKey: .enableAsyncShaderCompilation) ?? false
        disableMacroHLE            = try c.decodeIfPresent(Bool.self,   forKey: .disableMacroHLE)          ?? false
        preferredGPUVendor         = try c.decodeIfPresent(String.self, forKey: .preferredGPUVendor)       ?? ""
        scalingFilterLevel         = try c.decodeIfPresent(Int32.self,  forKey: .scalingFilterLevel)       ?? 0
        expandRAM                  = try c.decodeIfPresent(Bool.self,   forKey: .expandRAM)                ?? false
        ignoreMissingServices      = try c.decodeIfPresent(Bool.self,   forKey: .ignoreMissingServices)    ?? false
        
        controllerType1        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType1)        ?? ControllerType.none.rawValue)
        controllerType2        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType2)        ?? ControllerType.none.rawValue)
        controllerType3        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType3)        ?? ControllerType.none.rawValue)
        controllerType4        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType4)        ?? ControllerType.none.rawValue)
        controllerType5        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType5)        ?? ControllerType.none.rawValue)
        controllerType6        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType6)        ?? ControllerType.none.rawValue)
        controllerType7        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType7)        ?? ControllerType.none.rawValue)
        controllerType8        = ControllerType(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .controllerType8)        ?? ControllerType.none.rawValue)
        hideCursorMode         = HideCursorMode(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .hideCursorMode)         ?? HideCursorMode.onIdle.rawValue)!
        systemLanguage         = SystemLanguage(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .systemLanguage)         ?? SystemLanguage.americanEnglish.rawValue)!
        systemRegion           = NativeRegionCode(rawValue:    try c.decodeIfPresent(UInt32.self, forKey: .systemRegion)            ?? NativeRegionCode.USA.rawValue)!
        memoryManagerMode      = MemoryManagerMode(rawValue: try c.decodeIfPresent(UInt8.self, forKey: .memoryManagerMode)   ?? MemoryManagerMode.hostMappedUnsafe.rawValue)!
        loggingGraphicsDebugLevel = GraphicsDebugLevel(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .loggingGraphicsDebugLevel) ?? GraphicsDebugLevel.none.rawValue)!
        aspectRatio            = AspectRatio(rawValue:   try c.decodeIfPresent(UInt32.self, forKey: .aspectRatio)             ?? AspectRatio.fixed16x9.rawValue)!
        backendThreading       = BackendThreading(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .backendThreading)     ?? BackendThreading.off.rawValue)!
        graphicsBackend        = GraphicsBackend(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .graphicsBackend)       ?? GraphicsBackend.vulkan.rawValue)!
        antiAliasing           = AntiAliasing(rawValue:  try c.decodeIfPresent(UInt32.self, forKey: .antiAliasing)            ?? AntiAliasing.none.rawValue)!
        scalingFilter          = ScalingFilter(rawValue: try c.decodeIfPresent(UInt32.self, forKey: .scalingFilter)           ?? ScalingFilter.bilinear.rawValue)!
        
        graphicsShadersDumpPath = try c.decodeIfPresent(String.self, forKey: .graphicsShadersDumpPath)
    }
    
    static func loadFromJSON(at url: URL) throws -> Options {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Options.self, from: data)
    }
    
    func saveAsJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
