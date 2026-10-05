import Foundation

struct LongPressConfiguration: Equatable {
    static let defaultDuration: TimeInterval = 0.5
    let duration: TimeInterval
    init(duration: TimeInterval = defaultDuration) {
        self.duration = duration.isFinite ? min(1, max(0.3, duration)) : Self.defaultDuration
    }
}
