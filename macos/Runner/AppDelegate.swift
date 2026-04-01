import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var hotkeyChannel: HotkeyChannel?
    private var audioCaptureChannel: AudioCaptureChannel?
    private var pasteChannel: PasteChannel?
    private var soundChannel: SoundChannel?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Tray-only app — do not quit when the window closes.
        return false
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            return
        }

        let messenger = controller.engine.binaryMessenger

        // Register all platform channels.
        hotkeyChannel = HotkeyChannel(messenger: messenger)
        audioCaptureChannel = AudioCaptureChannel(messenger: messenger)
        pasteChannel = PasteChannel(messenger: messenger)
        soundChannel = SoundChannel(messenger: messenger)
    }
}
