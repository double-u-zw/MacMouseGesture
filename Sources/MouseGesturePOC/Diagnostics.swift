import Foundation

// Bounded memory log. No file I/O on input callbacks, no keyboard/window/app content.
final class Diagnostics {
    private let lock = NSLock()
    private var lines: [String] = []
    private let start = ProcessInfo.processInfo.systemUptime
    func log(_ level: String = "INFO", _ text: String) {
        let line = String(format: "%8.3f [%@] %@", ProcessInfo.processInfo.systemUptime - start, DiagnosticRedactor.redact(level), DiagnosticRedactor.redact(text))
        lock.lock()
        lines.append(line)
        if lines.count > 300 { lines.removeFirst(lines.count - 300) }
        lock.unlock()
    }
    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}

func monotonicTime() -> Double { ProcessInfo.processInfo.systemUptime }
