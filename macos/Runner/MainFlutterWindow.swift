import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.backgroundColor = .clear

    super.awakeFromNib()
  }

  // Always non-opaque so macOS composites the overlay window correctly
  // over other windows. window_manager's setAsFrameless() sets isOpaque=true
  // which breaks transparent overlay rendering — this override prevents that.
  override var isOpaque: Bool {
    get { return false }
    set { }
  }

  // Frameless/hidden-titlebar windows must explicitly allow becoming key/main
  // to receive keyboard input and appear in front when activated.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
