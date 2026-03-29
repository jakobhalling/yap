import 'dart:async';

import 'hotkey_service.dart';

/// Mock implementation of [HotkeyService] for use in tests.
///
/// Call [simulateDoubleTap] to manually fire the onDoubleTap stream.
class MockHotkeyService implements HotkeyService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool isStarted = false;
  int threshold = 400;
  String triggerKey = 'left_command';

  @override
  Stream<void> get onDoubleTap => _controller.stream;

  @override
  Future<void> start({String? triggerKey}) async {
    isStarted = true;
    if (triggerKey != null) this.triggerKey = triggerKey;
  }

  @override
  Future<void> stop() async {
    isStarted = false;
  }

  @override
  Future<void> setDoubleTapThreshold(int milliseconds) async {
    assert(milliseconds >= 200 && milliseconds <= 600);
    threshold = milliseconds;
  }

  @override
  Future<void> setTriggerKey(String key) async {
    triggerKey = key;
  }

  /// Simulate a double-tap event for testing purposes.
  void simulateDoubleTap() {
    _controller.add(null);
  }

  /// Dispose the underlying stream controller.
  void dispose() {
    _controller.close();
  }
}
