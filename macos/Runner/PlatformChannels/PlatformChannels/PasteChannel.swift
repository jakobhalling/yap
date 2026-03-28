import Cocoa
import FlutterMacOS

/// Handles the `com.yap.paste` platform channel.
///
/// Performs a clipboard save → set text → simulate Cmd+V → restore cycle.
/// Requires accessibility permissions (same as hotkey — user grants once).
class PasteChannel: NSObject {
    private let methodChannel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.yap.paste",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
    }

    // MARK: - MethodChannel handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "paste":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected 'text' argument",
                    details: nil
                ))
                return
            }
            pasteText(text, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Paste simulation

    private func pasteText(_ text: String, result: @escaping FlutterResult) {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents.
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // 2. Set new text on the pasteboard.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V keypress.
        let success = simulateCmdV()

        // 4. After a short delay, restore the original clipboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
        }

        result(success)
    }

    /// Simulate Cmd+V using CGEvent.
    private func simulateCmdV() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        // 'v' keycode is 9.
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
