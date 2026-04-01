import Cocoa
import FlutterMacOS

/// Handles the `com.yap.sound` platform channel.
///
/// Plays native macOS system sounds using NSSound.
class SoundChannel: NSObject {
    private let methodChannel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.yap.sound",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
    }

    // MARK: - MethodChannel handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "playStartSound":
            playSystemSound("Tink")
            result(nil)

        case "playStopSound":
            playSystemSound("Pop")
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - System sound playback

    private func playSystemSound(_ name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.stop()
            sound.play()
        }
    }
}
