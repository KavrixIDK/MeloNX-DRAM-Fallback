//
//  RumbleController.swift
//  MeloNX
//
//  Created by MediaMoots on 2025/5/24.
//

import CoreHaptics
import Foundation

class RumbleController {
    private final class HapticChannel {
        private let engine: CHHapticEngine
        private let hapticEventDuration: TimeInterval
        private var lowHapticPlayer: CHHapticPatternPlayer?
        private var highHapticPlayer: CHHapticPatternPlayer?
        
        init?(engine: CHHapticEngine?, hapticEventDuration: TimeInterval) {
            guard let engine else { return nil }
            
            self.engine = engine
            self.hapticEventDuration = hapticEventDuration
            
            do {
                try engine.start()
                
                try createPlayers()
            } catch {
                return nil
            }
        }
        
        func restart() {
            do {
                try lowHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
                try highHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
                
                try engine.start()
                try createPlayers()
            } catch {
                lowHapticPlayer = nil
                highHapticPlayer = nil
            }
        }
        
        func stop() {
            try? lowHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            try? highHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        }
        
        func update(
            lowAmplitude: Float,
            lowFrequency: Float,
            highAmplitude: Float,
            highFrequency: Float,
            rumbleMultiplier: Float
        ) {
            do {
                try sendParameters(
                    lowAmplitude: lowAmplitude,
                    lowFrequency: lowFrequency,
                    highAmplitude: highAmplitude,
                    highFrequency: highFrequency,
                    rumbleMultiplier: rumbleMultiplier
                )
            } catch {
                restart()
            }
        }
        
        private func sendParameters(
            lowAmplitude: Float,
            lowFrequency: Float,
            highAmplitude: Float,
            highFrequency: Float,
            rumbleMultiplier: Float
        ) throws {
            let lowIntensity = Self.clamp(lowAmplitude * rumbleMultiplier)
            let highIntensity = Self.clamp(highAmplitude * rumbleMultiplier)
            
            try lowHapticPlayer?.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: lowIntensity, relativeTime: 0),
                CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Self.sharpness(for: lowFrequency, fallback: 0), relativeTime: 0),
            ], atTime: 0)
            
            try highHapticPlayer?.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: highIntensity, relativeTime: 0),
                CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Self.sharpness(for: highFrequency, fallback: 1), relativeTime: 0),
            ], atTime: 0)
        }
        
        private func createPlayers() throws {
            lowHapticPlayer = try createPlayer(sharpness: 0)
            highHapticPlayer = try createPlayer(sharpness: 1)
            
            try sendParameters(lowAmplitude: 0, lowFrequency: 160, highAmplitude: 0, highFrequency: 320, rumbleMultiplier: 1)
            
            try lowHapticPlayer?.start(atTime: 0)
            try highHapticPlayer?.start(atTime: 0)
        }
        
        private func createPlayer(sharpness: Float) throws -> CHHapticPatternPlayer {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: 0,
                duration: hapticEventDuration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            
            return try engine.makePlayer(with: pattern)
        }
        
        private static func sharpness(for frequency: Float, fallback: Float) -> Float {
            guard frequency.isFinite, frequency > 0 else { return fallback }
            
            let minHz: Float = 40
            let maxHz: Float = 1252
            let normalized = (log2(clamp(frequency, minHz, maxHz)) - log2(minHz)) / (log2(maxHz) - log2(minHz))
            
            return clamp(normalized)
        }
        
        private static func clamp(_ value: Float, _ lower: Float = 0, _ upper: Float = 1) -> Float {
            min(upper, max(lower, value))
        }
    }
    
    private var leftChannel: HapticChannel?
    private var rightChannel: HapticChannel?
    private var fallbackChannel: HapticChannel?
    private let rumbleMultiplier: Float
    private let hapticQueue = DispatchQueue(label: "com.stossy11.MeloNX.rumble", qos: .userInteractive)
    
    private let hapticEventDuration: TimeInterval = 20
    private let restartGracePeriod: TimeInterval = 1.0
    private var playerRestartTimer: Timer?
    private var durationTimer: Timer?
    
    init (engine: CHHapticEngine?, rumbleMultiplier: Float) {
        self.rumbleMultiplier = rumbleMultiplier
        
        fallbackChannel = HapticChannel(engine: engine, hapticEventDuration: hapticEventDuration)
        setupPlayerRestartTimer()
    }
    
    init(leftEngine: CHHapticEngine?, rightEngine: CHHapticEngine?, fallbackEngine: CHHapticEngine?, rumbleMultiplier: Float) {
        self.rumbleMultiplier = rumbleMultiplier
        
        leftChannel = HapticChannel(engine: leftEngine, hapticEventDuration: hapticEventDuration)
        rightChannel = HapticChannel(engine: rightEngine, hapticEventDuration: hapticEventDuration)
        
        if leftChannel == nil || rightChannel == nil {
            leftChannel = nil
            rightChannel = nil
            fallbackChannel = HapticChannel(engine: fallbackEngine, hapticEventDuration: hapticEventDuration)
        }
        
        setupPlayerRestartTimer()
    }
    
    deinit {
        playerRestartTimer?.invalidate()
        playerRestartTimer = nil
        
        leftChannel?.stop()
        rightChannel?.stop()
        fallbackChannel?.stop()
    }
    
    private func setupPlayerRestartTimer() {
        playerRestartTimer?.invalidate()
        
        let restartInterval = hapticEventDuration - restartGracePeriod
        
        guard restartInterval > 0 else { return }
        
        playerRestartTimer = Timer.scheduledTimer(withTimeInterval: restartInterval, repeats: true) { [weak self] _ in
            self?.restartPlayers()
        }
    }
    
    public func rumble(lowFreq: Float, highFreq: Float, durationMs: UInt32? = nil) {
        let vibration = RumbleData.VibrationValue(
            amplitudeLow: lowFreq,
            frequencyLow: 160,
            amplitudeHigh: highFreq,
            frequencyHigh: 320
        )
        
        rumble(left: vibration, right: vibration, durationMs: durationMs)
    }
    
    public func rumble(data: RumbleData) {
        rumble(left: data.left, right: data.right, durationMs: data.durationMs)
    }
    
    private func rumble(left: RumbleData.VibrationValue, right: RumbleData.VibrationValue, durationMs: UInt32?) {
        hapticQueue.async { [weak self] in
            guard let self else { return }
            
            if leftChannel != nil, rightChannel != nil {
                leftChannel?.update(
                    lowAmplitude: left.amplitudeLow,
                    lowFrequency: left.frequencyLow,
                    highAmplitude: left.amplitudeHigh,
                    highFrequency: left.frequencyHigh,
                    rumbleMultiplier: rumbleMultiplier
                )
                rightChannel?.update(
                    lowAmplitude: right.amplitudeLow,
                    lowFrequency: right.frequencyLow,
                    highAmplitude: right.amplitudeHigh,
                    highFrequency: right.frequencyHigh,
                    rumbleMultiplier: rumbleMultiplier
                )
            } else {
                fallbackChannel?.update(
                    lowAmplitude: max(left.amplitudeLow, right.amplitudeLow),
                    lowFrequency: weightedFrequency(left.frequencyLow, left.amplitudeLow, right.frequencyLow, right.amplitudeLow, fallback: 160),
                    highAmplitude: max(left.amplitudeHigh, right.amplitudeHigh),
                    highFrequency: weightedFrequency(left.frequencyHigh, left.amplitudeHigh, right.frequencyHigh, right.amplitudeHigh, fallback: 320),
                    rumbleMultiplier: rumbleMultiplier
                )
            }
        }
        
        scheduleStopTimer(durationMs: durationMs)
    }
    
    private func restartPlayers() {
        hapticQueue.async { [weak self] in
            self?.leftChannel?.restart()
            self?.rightChannel?.restart()
            self?.fallbackChannel?.restart()
        }
    }
    
    private func scheduleStopTimer(durationMs: UInt32?) {
        DispatchQueue.main.async { [weak self] in
            self?.durationTimer?.invalidate()
            self?.durationTimer = nil
            
            guard let durationMs, durationMs > 0, durationMs != UInt32.max else { return }
            
            let durationSeconds = TimeInterval(durationMs) / 1000.0
            self?.durationTimer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { [weak self] _ in
                self?.rumble(lowFreq: 0, highFreq: 0)
            }
        }
    }
    
    private func weightedFrequency(_ firstFrequency: Float, _ firstAmplitude: Float, _ secondFrequency: Float, _ secondAmplitude: Float, fallback: Float) -> Float {
        let totalAmplitude = firstAmplitude + secondAmplitude
        
        guard totalAmplitude > 0 else { return fallback }
        
        return ((firstFrequency * firstAmplitude) + (secondFrequency * secondAmplitude)) / totalAmplitude
    }
}
