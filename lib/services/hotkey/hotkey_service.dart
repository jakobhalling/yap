/// Abstract interface for global hotkey detection.
///
/// The trigger key is Left Cmd on macOS and Left Alt on Windows.
/// A "double-tap" fires an event on [onDoubleTap].
abstract class HotkeyService {
  /// Stream that emits an event each time the user double-taps the trigger key.
  /// The trigger is Left Cmd on macOS, Left Alt on Windows.
  Stream<void> get onDoubleTap;

  /// Start listening for the global hotkey. Call once at app startup.
  /// Optionally pass a [triggerKey] identifier to use instead of the default.
  Future<void> start({String? triggerKey});

  /// Stop listening. Call on app shutdown.
  Future<void> stop();

  /// Update the double-tap detection window (in milliseconds).
  /// Default: 400ms. Range: 200–600ms.
  Future<void> setDoubleTapThreshold(int milliseconds);

  /// Change which modifier key is used for double-tap detection.
  /// Values: 'left_command', 'right_command', 'left_option', 'right_option',
  /// 'left_control', 'right_control', 'left_shift', 'right_shift',
  /// 'left_alt', 'right_alt', 'fn'.
  Future<void> setTriggerKey(String key);
}
