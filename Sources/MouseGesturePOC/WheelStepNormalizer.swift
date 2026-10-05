import Foundation

// One configuration source; injectable for deterministic tests, no speed settings UI.
struct WheelStepConfiguration {
    static let defaultContinuousThreshold = 10.0 // AppKit points; provisional pending hardware calibration
    static let defaultMinimumStepInterval = 0.04 // at most 25 actions/s, no delayed replay
    static let defaultAccumulationIdleInterval = 0.25
    let continuousThreshold: Double
    let minimumStepInterval: Double
    let accumulationIdleInterval: Double
    init(continuousThreshold: Double = Self.defaultContinuousThreshold,
         minimumStepInterval: Double = Self.defaultMinimumStepInterval,
         accumulationIdleInterval: Double = Self.defaultAccumulationIdleInterval) {
        self.continuousThreshold = continuousThreshold.isFinite && continuousThreshold > 0 ? continuousThreshold : Self.defaultContinuousThreshold
        self.minimumStepInterval = minimumStepInterval.isFinite && minimumStepInterval >= 0 ? minimumStepInterval : Self.defaultMinimumStepInterval
        self.accumulationIdleInterval = accumulationIdleInterval.isFinite && accumulationIdleInterval > 0 ? accumulationIdleInterval : Self.defaultAccumulationIdleInterval
    }
}

struct WheelScrollSample {
    let delta: Double
    let isContinuous: Bool
    let isDirectionInvertedFromDevice: Bool
    var isMomentum = false
    // The sole raw sign conversion. Positive device delta means physical wheel up.
    var physicalDelta: Double { isDirectionInvertedFromDevice ? -delta : delta }
    var direction: MouseWheelDirection? {
        guard physicalDelta.isFinite, physicalDelta != 0 else { return nil }
        return physicalDelta > 0 ? .up : .down
    }
}

struct WheelStepNormalizer {
    let configuration: WheelStepConfiguration
    private(set) var remainder = 0.0
    private var direction: MouseWheelDirection?
    private var continuous: Bool?
    private var lastSampleAt: Double?
    private var lastStepAt: Double?
    init(configuration: WheelStepConfiguration = .init()) { self.configuration = configuration }
    mutating func resetAccumulation() { remainder = 0; direction = nil; continuous = nil; lastSampleAt = nil }
    mutating func step(_ sample: WheelScrollSample, at time: Double) -> MouseWheelDirection? {
        guard time.isFinite, !sample.isMomentum, let nextDirection = sample.direction else { return nil }
        if nextDirection != direction || continuous != sample.isContinuous ||
            lastSampleAt.map({ time < $0 || time - $0 > configuration.accumulationIdleInterval }) == true {
            resetAccumulation()
        }
        direction = nextDirection; continuous = sample.isContinuous; lastSampleAt = time
        let threshold = sample.isContinuous ? configuration.continuousThreshold : 1
        let magnitude = abs(sample.physicalDelta)
        // Modulo discards excess FULL steps: a huge report cannot create a replay debt.
        let fractional = magnitude.truncatingRemainder(dividingBy: threshold)
        let accumulated = remainder + fractional
        let crossed = magnitude >= threshold || accumulated >= threshold
        remainder = accumulated.truncatingRemainder(dividingBy: threshold)
        guard crossed else { return nil }
        guard lastStepAt.map({ time >= $0 && time - $0 + 1e-9 >= configuration.minimumStepInterval }) ?? true else { return nil }
        lastStepAt = time
        return nextDirection
    }
}
