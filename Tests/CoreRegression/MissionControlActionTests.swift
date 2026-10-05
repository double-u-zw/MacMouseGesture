import Foundation
import GestureCore

private final class MissionFixture {
    var time = 100.0
    var permission = true
    var available = true
    var application: String? = "test.frontmost"
    var failPhase: GesturePhase?
    var frames: [GestureFrame] = []
    var messages: [String] = []
    lazy var action = MissionControlAction(queue: DispatchQueue(label: "tests.missionOneShot"),
        clock: { [unowned self] in self.time }, permissionGranted: { [unowned self] in self.permission },
        verticalAvailable: { [unowned self] in self.available }, frontmostApplication: { [unowned self] in self.application },
        postVertical: { [unowned self] frame in self.frames.append(frame); return frame.phase != self.failPhase },
        diagnostic: { [unowned self] in self.messages.append($0) }, automaticScheduling: false)
    func advance(_ elapsed: Double) { time = 100 + elapsed; action.advance() }
}

let missionControlActionChecks: [(String, () throws -> Void)] = [
    ("MC one-shot begins below completion with no immediate end", {
        let f = MissionFixture(); expectEqual(f.action.start(button: 4), .success)
        expectEqual(f.frames.map(\.phase), [.began]); expectEqual(f.frames[0].progress, 0.02, accuracy: 0.000001)
        expectTrue(f.action.isRunning); expectEqual(f.action.lastResult, nil)
    }),
    ("MC one-shot progresses at frame intervals and completes once", {
        let f = MissionFixture(); _ = f.action.start(button: 4)
        for index in 1...24 { f.advance(Double(index) / 120) }
        f.advance(0.21)
        expectEqual(f.frames.filter { $0.phase == .began }.count, 1)
        expectTrue(f.frames.filter { $0.phase == .changed }.count >= 20)
        expectEqual(f.frames.filter { $0.phase == .ended }.count, 1)
        expectEqual(f.frames.last?.progress, 1); expectFalse(f.action.isRunning); expectEqual(f.action.lastResult, .success)
        expectTrue(zip(f.frames, f.frames.dropFirst()).allSatisfy { $0.progress <= $1.progress })
    }),
    ("MC one-shot delayed delivery carries final update before end", {
        let f = MissionFixture(); _ = f.action.start(); f.advance(0.4)
        expectEqual(f.frames.map(\.phase), [.began, .changed, .ended]); expectEqual(f.frames.last?.progress, 1)
    }),
    ("MC one-shot idle repeated timer calls cannot duplicate action", {
        let f = MissionFixture(); _ = f.action.start(); f.advance(0.21)
        let count = f.frames.count
        for _ in 0..<100 { f.advance(1) }
        expectEqual(f.frames.count, count)
    }),
    ("MC one-shot permission denial posts nothing", {
        let f = MissionFixture(); f.permission = false
        expectEqual(f.action.start(button: 4), .permissionDenied); expectTrue(f.frames.isEmpty); expectFalse(f.action.isRunning)
    }),
    ("MC one-shot backend unavailable posts nothing", {
        let f = MissionFixture(); f.available = false
        expectEqual(f.action.start(), .systemFeatureUnavailable); expectTrue(f.frames.isEmpty)
    }),
    ("MC one-shot missing foreground application is diagnosed", {
        let f = MissionFixture(); f.application = nil
        expectEqual(f.action.start(), .noFrontmostApplication); expectTrue(f.frames.isEmpty)
        expectTrue(f.messages.contains { $0.contains("frontmost=none") && $0.contains("result=noFrontmostApplication") })
    }),
    ("MC one-shot overlapping request cannot interleave frames", {
        let f = MissionFixture(); _ = f.action.start(button: 4)
        expectEqual(f.action.start(button: 5), .unsupported); expectEqual(f.frames.count, 1)
        f.advance(0.21); expectEqual(f.action.lastResult, .success)
    }),
    ("MC one-shot first post failure reports and cancels once", {
        let f = MissionFixture(); f.failPhase = .began
        expectEqual(f.action.start(), .eventPostFailed); expectEqual(f.frames.map(\.phase), [.began, .cancelled])
        expectFalse(f.action.isRunning); f.advance(0.4); expectEqual(f.frames.count, 2)
    }),
    ("MC one-shot update and end failures cannot report success", {
        for phase in [GesturePhase.changed, .ended] {
            let f = MissionFixture(); _ = f.action.start(); f.failPhase = phase; f.advance(0.21)
            expectEqual(f.action.lastResult, .eventPostFailed); expectEqual(f.frames.last?.phase, .cancelled)
            expectFalse(f.action.isRunning)
        }
    }),
    ("MC one-shot permission loss cancels without completing", {
        let f = MissionFixture(); _ = f.action.start(); f.permission = false; f.advance(0.05)
        expectEqual(f.action.lastResult, .permissionDenied); expectEqual(f.frames.map(\.phase), [.began, .cancelled])
    }),
    ("MC one-shot lifecycle cancellation releases then restarts fresh", {
        let f = MissionFixture(); _ = f.action.start(); f.advance(0.05)
        f.action.cancel(reason: "physical drag takes priority"); f.action.cancel(reason: "stop")
        expectEqual(f.frames.filter { $0.phase == .cancelled }.count, 1); expectFalse(f.action.isRunning)
        expectEqual(f.action.start(), .success); expectEqual(f.frames.last?.phase, .began)
        expectEqual(f.frames.last?.progress, 0.02)
        f.action.cancel(reason: "application exit")
    }),
    ("MC one-shot invalid clock fails safely", {
        let f = MissionFixture(); f.time = .nan; expectEqual(f.action.start(), .unknownFailure); expectTrue(f.frames.isEmpty)
    }),
    ("MC one-shot diagnostics expose path result and foreground only", {
        let f = MissionFixture(); _ = f.action.start(button: 4); f.advance(0.21)
        expectTrue(f.messages.contains { $0.contains("button=4 action=missionControl executor=nativeHID-oneShot frontmost=test.frontmost stage=request") })
        expectTrue(f.messages.contains { $0.contains("stage=complete result=success") && $0.contains("Dock response requires real-device acceptance") })
    })
]
