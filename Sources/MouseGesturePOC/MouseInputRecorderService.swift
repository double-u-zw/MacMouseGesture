import AppKit
import ApplicationServices

// Main-run-loop tap, installed only while a recording sheet or swallowed release
// is alive. Uses existing Accessibility permission; never posts mouse events.
final class MouseInputRecorderService {
    let recorder: MouseInputRecorder
    var onStatus: ((MouseRecordingStatus) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var open = false
    private var generation = 0
    init(recorder: MouseInputRecorder) { self.recorder = recorder }
    func begin() {
        generation += 1; open = true
        recorder.cancel()
        guard AXIsProcessTrusted() else {
            onStatus?(.failed("需要辅助功能权限才能录制鼠标输入。")); return
        }
        if tap == nil {
            let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
            let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
            tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    let service = Unmanaged<MouseInputRecorderService>.fromOpaque(context).takeUnretainedValue()
                    return service.receive(type: type, event: event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque())
            guard let tap else {
                onStatus?(.failed("无法开始录制，请检查当前开发版的辅助功能权限。")); return
            }
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            guard let source else {
                removeTap(); onStatus?(.failed("无法建立录制事件源，请重新录制。")); return
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        recorder.begin(); onStatus?(.waiting)
    }
    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recorder.cancel()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            publish(.failed("录制被系统中断，请重新录制。"))
            return Unmanaged.passUnretained(event)
        }
        // Never start a capture in another app; an already swallowed up still drains.
        if !NSApp.isActive { recorder.cancel() }
        let decision = recorder.capture(type: type, event: event)
        switch decision {
        case .captured(let input): publish(.captured(input)); return nil
        case .consume:
            if !open && !recorder.hasPendingRelease {
                DispatchQueue.main.async { [weak self] in self?.removeTapIfFinished() }
            }
            return nil
        case .primaryUnsupported:
            publish(.primaryUnsupported); return Unmanaged.passUnretained(event)
        case .pass: return Unmanaged.passUnretained(event)
        }
    }
    private func publish(_ status: MouseRecordingStatus) {
        let current = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.open, self.generation == current else { return }
            self.onStatus?(status)
        }
    }
    func end(_ reason: MouseRecordingEndReason) {
        open = false; generation += 1; recorder.cancel(reason)
        onStatus?(.idle); removeTapIfFinished()
    }
    private func removeTapIfFinished() {
        guard !open, !recorder.hasPendingRelease else { return }
        removeTap()
    }
    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }
    func shutdown() { open = false; generation += 1; recorder.shutdown(); removeTap() }
    deinit { shutdown() }
}
