/// Abstract interface for global hotkey detection.
///
/// The trigger key is Left Cmd on macOS and Left Alt on Windows.
/// A "double-tap" fires an event on [onDoubleTap].
abstract class HotkeyService {
  /// Stream that emits an event each time the user double-taps the trigger key.
  /// The trigger is Left Cmd on macOS, Left Alt on Windows.
  Stream<void> get onDoubleTap;

  /// Start listening for the global hotkey. Call once at app startup.
  Future<void> start();

  /// Stop listening. Call on app shutdown.
  Future<void> stop();

  /// Update the double-tap detection window (in milliseconds).
  /// Default: 400ms. Range: 200–600ms.
  Future<void> setDoubleTapThreshold(int milliseconds);
}
