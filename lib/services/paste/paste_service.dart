/// Abstract interface for simulated paste into any application.
///
/// The native side handles the full clipboard save → copy → simulate
/// keypress → restore flow because timing is critical at the OS level.
abstract class PasteService {
  /// Save current clipboard, put [text] on clipboard, simulate Ctrl+V / Cmd+V,
  /// then restore the original clipboard after a short delay.
  /// Returns true if paste was simulated, false if it fell back to clipboard-only.
  Future<bool> pasteText(String text);
}
