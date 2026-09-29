import Foundation
import Darwin

// Sampled no more than once per second by diagnostics. CPU=100% means one core.
// RSS is resident memory, not a leak detector or physical-footprint estimate.
final class PerformanceSampler {
    private var previousTime: Double?
    private var previousCPU = 0.0
    private var baselineRSS: Double?
    private var maximumRSS = 0.0
    private var maximumCPU = 0.0
    private var completedCheckpoint = 0
    private var checkpoints: [String] = []
    private var cached = "Performance: awaiting first sample"

    func sample(completed: Int) -> String {
        let now = monotonicTime()
        if let previousTime, now - previousTime < 1 { return cached }
        var usage = rusage()
        let resourceOK = getrusage(RUSAGE_SELF, &usage) == 0
        let cpuSeconds = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) +
            Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let rss = Double(info.resident_size) / 1_048_576
        let cpu = previousTime.map { max(0, (cpuSeconds - previousCPU) / (now - $0) * 100) }
        if result == KERN_SUCCESS {
            if baselineRSS == nil { baselineRSS = rss }
            maximumRSS = max(maximumRSS, rss)
        }
        if let cpu, resourceOK { maximumCPU = max(maximumCPU, cpu) }
        previousTime = now; previousCPU = cpuSeconds
        if result == KERN_SUCCESS && completed / 100 > completedCheckpoint {
            completedCheckpoint = completed / 100
            checkpoints.append(String(format: "%d completed: RSS=%.1f MiB", completed, rss))
            if checkpoints.count > 10 { checkpoints.removeFirst() }
        }
        let cpuText = resourceOK ? cpu.map { String(format: "%.2f%%", $0) } ?? "warming up" : "unavailable"
        let memory = result == KERN_SUCCESS ? String(format: "RSS=%.1f MiB; launch sample=%.1f MiB; sampled max=%.1f MiB", rss, baselineRSS ?? rss, maximumRSS) : "RSS unavailable"
        cached = "Performance: CPU=\(cpuText); sampled CPU max=\(String(format: "%.2f%%", maximumCPU)); \(memory)\n" +
            "Memory checkpoints: \(checkpoints.isEmpty ? "awaiting 100 completed gestures" : checkpoints.joined(separator: "; ")) (1s samples; process lifetime)"
        return cached
    }
}
