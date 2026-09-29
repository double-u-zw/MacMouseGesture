import Foundation
import IOKit.hid

// Read-only IOHIDManager observer. Never seize devices and never inject from this path.
// Device identity and usage values complement CG's zero-based button numbers.
final class HIDInputBackend {
    private var manager: IOHIDManager?
    private let queue = DispatchQueue(label: "MouseGesture.HID", qos: .userInitiated)
    private let log: Diagnostics
    private let lock = NSLock()
    private var values = 0
    private var motion = 0
    private var dx = 0
    private var dy = 0
    private var firstTime = 0.0
    private var lastTime = 0.0
    var disconnected: (() -> Void)?
    init(log: Diagnostics) { self.log = log }
    func start() -> IOReturn {
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = m
        IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                                         kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(m, { context, _, _, device in
            guard let context else { return }
            let owner = Unmanaged<HIDInputBackend>.fromOpaque(context).takeUnretainedValue()
            let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
            let product = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber
            owner.log.log("INFO", "HID mouse vendor=\(vendor?.intValue ?? -1) product=\(product?.intValue ?? -1)")
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(m, { context, _, _, _ in
            guard let context else { return }
            let owner = Unmanaged<HIDInputBackend>.fromOpaque(context).takeUnretainedValue()
            owner.log.log("INFO", "HID mouse removed; cancelling active experiment")
            owner.disconnected?()
        }, context)
        IOHIDManagerRegisterInputValueCallback(m, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<HIDInputBackend>.fromOpaque(context).takeUnretainedValue().receive(value)
        }, context)
        IOHIDManagerSetDispatchQueue(m, queue)
        // Retain until asynchronous cancellation drains every callback.
        IOHIDManagerSetCancelHandler(m) { [self] in manager = nil }
        let result = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerActivate(m)
        log.log(result == kIOReturnSuccess ? "INFO" : "ERROR", "HID open=\(String(format: "0x%08x", result)); no device seizure")
        return result
    }
    private func receive(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let amount = IOHIDValueGetIntegerValue(value)
        lock.lock()
        values += 1
        if page == kHIDPage_GenericDesktop && (usage == kHIDUsage_GD_X || usage == kHIDUsage_GD_Y) {
            motion += 1
            if usage == kHIDUsage_GD_X { dx += amount } else { dy += amount }
            let time = monotonicTime()
            if firstTime == 0 { firstTime = time }; lastTime = time
        }
        lock.unlock()
        if page == kHIDPage_Button {
            // Button edges are rare; motion is counters only, never per-value string formatting.
            log.log("DEBUG", "HID usage=\(usage) \(amount == 0 ? "UP" : "DOWN") (not assumed equal to CG number)")
        }
    }
    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        return "HID values=\(values); axis values=\(motion); dx=\(dx) dy=\(dy). Axis value count is NOT polling rate."
    }
    func stop() {
        guard let m = manager else { return }
        IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerCancel(m)
    }
}
