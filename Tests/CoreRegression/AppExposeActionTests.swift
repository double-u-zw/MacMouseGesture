import Foundation
import GestureCore

private final class ExposeFixture {
    var time = 100.0
    var permission = true
    var available = true
    var enabled: Bool? = true
    var target = AppExposeTarget(application: "test.frontmost", result: .success, reason: "AX window")
    var inspections = 0
    var failPhase: GesturePhase?
    var frames: [GestureFrame] = []
    var messages: [String] = []
    lazy var action = AppExposeAction(queue: DispatchQueue(label: "tests.appExpose"),
        clock: { [unowned self] in self.time }, permissionGranted: { [unowned self] in self.permission },
        inspectTarget: { [unowned self] in self.inspections += 1; return self.target },
        systemEnabled: { [unowned self] in self.enabled }, verticalAvailable: { [unowned self] in self.available },
        postVertical: { [unowned self] frame in self.frames.append(frame); return frame.phase != self.failPhase },
        diagnostic: { [unowned self] in self.messages.append($0) }, automaticScheduling: false)
    func advance(_ elapsed: Double) { time = 100 + elapsed; action.advance() }
}

let appExposeActionChecks: [(String, () throws -> Void)] = [
    ("App Expose starts current application's down gesture without immediate end", {
        let f = ExposeFixture(); expectEqual(f.action.start(button: 4), .success)
        expectEqual(f.frames.map(\.phase), [.began]); expectEqual(f.frames[0].progress, -0.02, accuracy: 0.000001)
        expectTrue(f.action.isRunning); expectEqual(f.action.lastResult, nil)
    }),
    ("App Expose mirrors progress and velocity through completion once", {
        let f = ExposeFixture(); _ = f.action.start()
        for index in 1...24 { f.advance(Double(index) / 120) }
        f.advance(0.21)
        expectEqual(f.frames.filter { $0.phase == .began }.count, 1)
        expectTrue(f.frames.filter { $0.phase == .changed }.count >= 20)
        expectEqual(f.frames.filter { $0.phase == .ended }.count, 1)
        expectEqual(f.frames.last?.progress, -1); expectEqual(f.action.lastResult, .success)
        expectTrue(f.frames.allSatisfy { $0.progress < 0 && $0.velocity <= 0 })
        expectTrue(f.frames.contains { $0.velocity < 0 })
        expectTrue(zip(f.frames, f.frames.dropFirst()).allSatisfy { $0.progress >= $1.progress })
    }),
    ("App Expose delayed delivery finishes with update before end", {
        let f = ExposeFixture(); _ = f.action.start(); f.advance(0.4)
        expectEqual(f.frames.map(\.phase), [.began, .changed, .ended]); expectEqual(f.frames.last?.progress, -1)
    }),
    ("App Expose idle advance cannot repeat execution", {
        let f = ExposeFixture(); _ = f.action.start(); f.advance(0.21)
        let count = f.frames.count
        for _ in 0..<100 { f.advance(1) }
        expectEqual(f.frames.count, count); expectFalse(f.action.isRunning)
    }),
    ("App Expose permission denial skips AX inspection and event posting", {
        let f = ExposeFixture(); f.permission = false
        expectEqual(f.action.start(), .permissionDenied); expectEqual(f.inspections, 0); expectTrue(f.frames.isEmpty)
    }),
    ("App Expose missing frontmost application posts nothing", {
        let f = ExposeFixture(); f.target = AppExposeTarget(application: nil, result: .noFrontmostApplication, reason: "missing")
        expectEqual(f.action.start(), .noFrontmostApplication); expectTrue(f.frames.isEmpty)
    }),
    ("App Expose absent window unsupported AX and inspection failure are distinguished", {
        for result in [ActionExecutionResult.noFocusedWindow, .unsupported, .unknownFailure, .permissionDenied, .cancelled] {
            let f = ExposeFixture(); f.target = AppExposeTarget(application: "test.frontmost", result: result, reason: "inspection rejected")
            expectEqual(f.action.start(), result); expectEqual(f.action.lastResult, result); expectTrue(f.frames.isEmpty)
            expectTrue(f.messages.contains { $0.contains("result=\(result.rawValue)") && $0.contains("inspection rejected") })
        }
    }),
    ("App Expose inconsistent successful target without app fails safely", {
        let f = ExposeFixture(); f.target = AppExposeTarget(application: nil, result: .success, reason: "inconsistent")
        expectEqual(f.action.start(), .noFrontmostApplication); expectTrue(f.frames.isEmpty)
    }),
    ("App Expose disabled Dock gesture is diagnosed and not posted", {
        let f = ExposeFixture(); f.enabled = false
        expectEqual(f.action.start(button: 5), .systemFeatureUnavailable); expectTrue(f.frames.isEmpty)
        expectTrue(f.messages.contains { $0.contains("systemGestureEnabled=false") })
        expectTrue(f.messages.contains { $0.contains("Dock App Exposé gesture disabled") })
    }),
    ("App Expose absent Dock override is explicitly recorded", {
        let f = ExposeFixture(); f.enabled = nil
        expectEqual(f.action.start(), .success)
        expectTrue(f.messages.contains { $0.contains("systemGestureEnabled=notOverridden") })
        f.advance(0.21); expectEqual(f.action.lastResult, .success)
    }),
    ("App Expose unavailable native backend posts nothing", {
        let f = ExposeFixture(); f.available = false
        expectEqual(f.action.start(), .systemFeatureUnavailable); expectEqual(f.action.lastResult, .systemFeatureUnavailable)
        expectTrue(f.frames.isEmpty)
    }),
    ("App Expose overlapping request preserves original target", {
        let f = ExposeFixture(); _ = f.action.start(button: 4)
        f.target = AppExposeTarget(application: "different.app", result: .success, reason: "window")
        expectEqual(f.action.start(button: 5), .unsupported); expectEqual(f.inspections, 1); expectEqual(f.frames.count, 1)
        f.advance(0.21); expectEqual(f.action.lastResult, .success)
        expectTrue(f.messages.contains { $0.contains("frontmost=test.frontmost stage=complete") })
    }),
    ("App Expose first event failure cancels negative progress and reports failure", {
        let f = ExposeFixture(); f.failPhase = .began
        expectEqual(f.action.start(), .eventPostFailed); expectEqual(f.frames.map(\.phase), [.began, .cancelled])
        expectEqual(f.frames.last?.progress, -0.02); expectFalse(f.action.isRunning)
        f.advance(0.21); expectEqual(f.frames.count, 2)
    }),
    ("App Expose update or terminal failure cannot report success", {
        for phase in [GesturePhase.changed, .ended] {
            let f = ExposeFixture(); _ = f.action.start(); f.failPhase = phase; f.advance(0.21)
            expectEqual(f.action.lastResult, .eventPostFailed); expectEqual(f.frames.last?.phase, .cancelled)
            expectEqual(f.frames.last?.progress, -1); expectFalse(f.action.isRunning)
        }
    }),
    ("App Expose permission loss cancels and releases state", {
        let f = ExposeFixture(); _ = f.action.start(); f.permission = false; f.advance(0.05)
        expectEqual(f.action.lastResult, .permissionDenied); expectEqual(f.frames.map(\.phase), [.began, .cancelled])
        expectFalse(f.action.isRunning)
    }),
    ("App Expose physical drag stop or exit cancellation restarts fresh", {
        let f = ExposeFixture(); _ = f.action.start(); f.advance(0.05)
        f.action.cancel(reason: "physical drag takes priority"); f.action.cancel(reason: "stop")
        expectEqual(f.frames.filter { $0.phase == .cancelled }.count, 1); expectFalse(f.action.isRunning)
        expectEqual(f.action.lastResult, .cancelled)
        expectEqual(f.action.start(), .success); expectEqual(f.frames.last?.progress, -0.02)
        f.action.cancel(reason: "application exit")
    }),
    ("App Expose invalid clock fails without posting", {
        let f = ExposeFixture(); f.time = .nan
        expectEqual(f.action.start(), .unknownFailure); expectTrue(f.frames.isEmpty)
    }),
    ("App Expose diagnostics identify button foreground settings and submitted result", {
        let f = ExposeFixture(); _ = f.action.start(button: 5); f.advance(0.21)
        expectTrue(f.messages.contains { $0.contains("button=5 action=appExpose executor=nativeHID-oneShot frontmost=test.frontmost stage=request") })
        expectTrue(f.messages.contains { $0.contains("stage=complete result=success") && $0.contains("Dock response requires real-device acceptance") })
        expectFalse(f.messages.contains { $0.contains("action=missionControl") })
    }),
    ("App Expose executor cancels competing one-shot and lifecycle cancellation reaches adapter", {
        let f = ExposeFixture()
        var missionFrames: [GestureFrame] = []
        let mission = MissionControlAction(queue: DispatchQueue(label: "tests.exposeInterleaving"), clock: { f.time },
            permissionGranted: { true }, verticalAvailable: { true }, frontmostApplication: { "test.app" },
            postVertical: { missionFrames.append($0); return true }, automaticScheduling: false)
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { _ in true },
            missionControl: mission, appExpose: f.action)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .missionControl), button: 4))
        expectTrue(executor.execute(ButtonClickConfiguration(action: .appExpose), button: 5))
        expectEqual(missionFrames.map(\.phase), [.began, .cancelled]); expectFalse(mission.isRunning)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .missionControl), button: 4))
        expectEqual(f.frames.map(\.phase), [.began, .cancelled]); expectFalse(f.action.isRunning)
        executor.cancelMissionControl(reason: "stop")
        expectTrue(executor.execute(ButtonClickConfiguration(action: .appExpose), button: 5))
        executor.cancelAppExpose(reason: "new physical side-button press")
        expectFalse(f.action.isRunning); expectEqual(f.action.lastResult, .cancelled)
    })
]
