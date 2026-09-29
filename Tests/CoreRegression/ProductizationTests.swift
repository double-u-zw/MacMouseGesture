import Foundation
import Darwin

struct ProductizationTests {
    func testRedaction() {
        for name in ["alice", "中文用户名", "user name"] {
            for tail in ["/", "/Desktop/private file.txt", "/Documents/秘密.txt"] {
                let raw = "/Users/\(name)\(tail)"
                for value in [raw, "file://" + raw, raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!] {
                    let result = DiagnosticRedactor.redact("Error: \(value)\nBackend: ready")
                    expectFalse(result.contains(name))
                    expectFalse(result.contains("private file"))
                    expectFalse(result.contains("秘密"))
                    expectTrue(result.contains("Backend: ready"))
                    expectEqual(DiagnosticRedactor.redact(result), result)
                }
            }
        }
    }
    func testLogBoundary() {
        let log = Diagnostics()
        log.log("ERROR", "startup /Users/alice/Documents/Secret.txt")
        log.log("WARN", "permission file:///Users/user%20name/Desktop/foo")
        expectFalse(log.snapshot().contains("alice"))
        expectFalse(log.snapshot().contains("user name"))
        expectFalse(log.snapshot().contains("Secret"))
        for _ in 0..<305 { log.log("INFO", "bounded") }
        expectEqual(log.snapshot().split(separator: "\n").count, 300)
    }
    func testLock() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var first: SingleInstance? = SingleInstance()
        expectEqual(first!.acquire(directory: folder), .acquired)
        expectEqual(SingleInstance().acquire(directory: folder), .alreadyRunning)
        first = nil
        expectEqual(SingleInstance().acquire(directory: folder), .acquired)
    }
    func testProcessLock() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        func process(_ mode: String) -> Process {
            let p = Process(); p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            p.arguments = ["--lock-fixture", folder.path, mode]; return p
        }
        let owner = process("hold"); let pipe = Pipe(); owner.standardOutput = pipe
        try owner.run()
        defer { if owner.isRunning { owner.terminate(); owner.waitUntilExit() } }
        expectTrue(String(data: pipe.fileHandleForReading.availableData, encoding: .utf8)!.contains("acquired"))
        let other = process("once"); try other.run(); other.waitUntilExit()
        expectEqual(other.terminationStatus, 23)
        kill(owner.processIdentifier, SIGKILL); owner.waitUntilExit()
        let replacement = process("once"); try replacement.run(); replacement.waitUntilExit()
        expectEqual(replacement.terminationStatus, 0)
    }
    func testUnsafeLock() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("instance.lock").path, withDestinationPath: "/dev/null")
        expectEqual(SingleInstance().acquire(directory: folder), .unavailable)
    }
    func testOnboarding() {
        let suite = "test.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var state = OnboardingState()
        expectTrue(OnboardingState.needsWelcome(defaults))
        state.persistCompletion(defaults)
        expectTrue(OnboardingState.needsWelcome(defaults))
        state.beginTest(at: 10, buttons: 100)
        state.observe(buttons: 100)
        expectFalse(state.detectedSideButton)
        expectFalse(state.waitingHint(at: 21))
        expectTrue(state.waitingHint(at: 22))
        state.observe(buttons: 101)
        expectFalse(state.waitingHint(at: 30))
        expectFalse(state.canComplete(accessibility: true, running: true))
        state.confirmedGesture = true
        expectFalse(state.canComplete(accessibility: false, running: true))
        expectFalse(state.canComplete(accessibility: true, running: false))
        expectTrue(state.canComplete(accessibility: true, running: true))
        state.step = .complete; state.persistCompletion(defaults)
        expectFalse(OnboardingState.needsWelcome(defaults))
        state.beginTest(at: 40, buttons: 101)
        expectFalse(state.detectedSideButton)
        expectFalse(state.confirmedGesture)
    }
    func testPermissionDisplay() {
        expectEqual(PermissionPresentation.accessibility(false, completed: false), "未授权")
        expectEqual(PermissionPresentation.accessibility(false, completed: true), "需要重新授权")
        expectEqual(PermissionPresentation.accessibility(true, completed: true), "已授权")
        expectEqual(PermissionPresentation.inputMonitoring(false), "未授权（可选）")
        expectEqual(PermissionPresentation.inputMonitoring(true), "已授权")
    }
}
