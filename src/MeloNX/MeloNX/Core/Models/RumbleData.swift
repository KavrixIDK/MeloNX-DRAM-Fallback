//
//  RumbleData.swift
//  MeloNX
//
//  Created by Stossy11 on 14/11/2025.
//

import Foundation

struct RumbleData {
    struct VibrationValue {
        var amplitudeLow: Float
        var frequencyLow: Float
        var amplitudeHigh: Float
        var frequencyHigh: Float
    }

    var lowFrequency: Float
    var highFrequency: Float
    var durationMs: UInt32

    var left: VibrationValue
    var right: VibrationValue

    private static let legacyByteCount = 12
    private static let highDefinitionByteCount = 44

    init?(data: Data) {
        guard let rumbleData = data.withUnsafeBytes({
            RumbleData(bytes: $0.baseAddress, byteCount: data.count)
        }) else { return nil }

        self = rumbleData
    }

    init?(callbackData: CallbackData) {
        guard let ptr = callbackData.ptr else { return nil }
        self.init(bytes: UnsafeRawPointer(ptr), byteCount: Int(callbackData.len))
    }

    private init?(bytes: UnsafeRawPointer?, byteCount: Int) {
        guard let bytes, byteCount >= Self.legacyByteCount else { return nil }

        lowFrequency = Self.readFloat(bytes, offset: 0)
        highFrequency = Self.readFloat(bytes, offset: 4)
        durationMs = bytes.load(fromByteOffset: 8, as: UInt32.self)

        if byteCount >= Self.highDefinitionByteCount {
            left = VibrationValue(
                amplitudeLow: Self.readFloat(bytes, offset: 12),
                frequencyLow: Self.readFloat(bytes, offset: 16),
                amplitudeHigh: Self.readFloat(bytes, offset: 20),
                frequencyHigh: Self.readFloat(bytes, offset: 24)
            )

            right = VibrationValue(
                amplitudeLow: Self.readFloat(bytes, offset: 28),
                frequencyLow: Self.readFloat(bytes, offset: 32),
                amplitudeHigh: Self.readFloat(bytes, offset: 36),
                frequencyHigh: Self.readFloat(bytes, offset: 40)
            )
        } else {
            left = VibrationValue(
                amplitudeLow: lowFrequency,
                frequencyLow: 160,
                amplitudeHigh: highFrequency,
                frequencyHigh: 320
            )
            right = left
        }
    }

    private static func readFloat(_ bytes: UnsafeRawPointer, offset: Int) -> Float {
        bytes.load(fromByteOffset: offset, as: Float.self)
    }
}
