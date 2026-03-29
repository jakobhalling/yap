import Cocoa
import FlutterMacOS

/// Handles the `com.yap.hotkey` platform channel.
///
/// Uses CGEventTap to detect double-taps of a configurable modifier key.
/// Requires accessibility permissions (AXIsProcessTrusted).
class HotkeyChannel: NSObject, FlutterStreamHandler {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var threshold: Int = 400 // milliseconds
    private var lastTapTime: UInt64 = 0

    // Configurable trigger key (default: Left Command)
    private var triggerKeyCode: UInt16 = 55
    private var triggerFlagMask: CGEventFlags = .maskCommand

    // Map of key identifiers to (keycode, flag mask)
    private static let keyMap: [String: (UInt16, CGEventFlags)] = [
        "left_command":  (55, .maskCommand),
        "right_command": (54, .maskCommand),
        "left_option":   (58, .maskAlternate),
        "right_option":  (61, .maskAlternate),
        "left_alt":      (58, .maskAlternate),
        "right_alt":     (61, .maskAlternate),
        "left_control":  (59, .maskControl),
        "right_control": (62, .maskControl),
        "left_shift":    (56, .maskShift),
        "right_shift":   (60, .maskShift),
        "fn":            (63, .maskSecondaryFn),
    ]

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.yap.hotkey",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.yap.hotkey/events",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
        eventChannel.setStreamHandler(self)
    }

    // MARK: - MethodChannel handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            if let args = call.arguments as? [String: Any] {
                if let t = args["threshold"] as? Int {
                    threshold = t
                }
                if let key = args["triggerKey"] as? String {
                    applyTriggerKey(key)
                }
            }
            startMonitoring(result: result)

        case "stop":
            stopMonitoring()
            result(nil)

        case "setThreshold":
            if let args = call.arguments as? [String: Any],
               let t = args["threshold"] as? Int {
                threshold = max(200, min(600, t))
            }
            result(nil)

        case "setTriggerKey":
            if let args = call.arguments as? [String: Any],
               let key = args["key"] as? String {
                applyTriggerKey(key)
                // Reset tap state when key changes
                lastTapTime = 0
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Trigger key configuration

    private func applyTriggerKey(_ key: String) {
        if let mapping = HotkeyChannel.keyMap[key] {
            triggerKeyCode = mapping.0
            triggerFlagMask = mapping.1
        }
    }

    // MARK: - Monitoring

    private func startMonitoring(result: @escaping FlutterResult) {
        // Check accessibility permission.
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            result(FlutterError(
                code: "ACCESSIBILITY_NOT_GRANTED",
                message: "Accessibility permission is required for global hotkey detection.",
                details: nil
            ))
            return
        }

        // Create event tap for flagsChanged (modifier keys).
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            result(FlutterError(
                code: "TAP_FAILED",
                message: "Could not create CGEventTap",
                details: nil
            ))
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        result(nil)
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Called from the C callback; checks for configured modifier key double-tap.
    fileprivate func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == triggerKeyCode else { return }

        let flags = event.flags
        let keyDown = flags.contains(triggerFlagMask)

        // We only care about key-down (flag set).
        guard keyDown else { return }

        let now = mach_absolute_time()
        let elapsed = machToMilliseconds(now - lastTapTime)
        lastTapTime = now

        if elapsed > 0 && elapsed <= Double(threshold) {
            // Double-tap detected.
            lastTapTime = 0 // reset so triple-tap doesn't re-fire
            DispatchQueue.main.async { [weak self] in
                self?.eventSink?(nil)
            }
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Helpers

    private func machToMilliseconds(_ elapsed: UInt64) -> Double {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = Double(elapsed) * Double(info.numer) / Double(info.denom)
        return nanos / 1_000_000.0
    }
}

// MARK: - C callback for CGEventTap

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let channel = Unmanaged<HotkeyChannel>.fromOpaque(userInfo).takeUnretainedValue()
    channel.handleFlagsChanged(event)
    return Unmanaged.passRetained(event)
}
