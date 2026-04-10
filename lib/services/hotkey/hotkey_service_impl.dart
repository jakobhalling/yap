import 'dart:async';

import 'package:flutter/services.dart';

import '../log_service.dart';
import 'hotkey_service.dart';

/// Platform-channel backed implementation of [HotkeyService].
///
/// Communicates with native code over:
/// - `MethodChannel('com.yap.hotkey')` for start / stop / setThreshold
/// - `EventChannel('com.yap.hotkey/events')` for the onDoubleTap stream
class HotkeyServiceImpl implements HotkeyService {
  HotkeyServiceImpl({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('com.yap.hotkey'),
        _eventChannel =
            eventChannel ?? const EventChannel('com.yap.hotkey/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamController<void>? _controller;
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  Stream<void> get onDoubleTap {
    _controller ??= StreamController<void>.broadcast();
    return _controller!.stream;
  }

  @override
  Future<void> start({int threshold = 400, String? triggerKey}) async {
    _controller ??= StreamController<void>.broadcast();

    // Subscribe to the native event stream.
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((_) {
      _controller?.add(null);
    }, onError: (Object error) {
      _controller?.addError(error);
    });

    final args = <String, dynamic>{'threshold': threshold};
    if (triggerKey != null) {
      args['triggerKey'] = triggerKey;
    }
    await _methodChannel.invokeMethod<void>('start', args);
  }

  @override
  Future<void> stop() async {
    Log.i('Hotkey', 'Monitoring stopped');
    await _methodChannel.invokeMethod<void>('stop');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  Future<void> setDoubleTapThreshold(int milliseconds) async {
    assert(milliseconds >= 200 && milliseconds <= 600,
        'Threshold must be between 200 and 600 ms');
    await _methodChannel.invokeMethod<void>(
      'setThreshold',
      <String, dynamic>{'threshold': milliseconds},
    );
  }

  @override
  Future<void> setTriggerKey(String key) async {
    await _methodChannel.invokeMethod<void>(
      'setTriggerKey',
      <String, dynamic>{'key': key},
    );
  }

  @override
  Future<bool> checkAccessibility() async {
    final result = await _methodChannel.invokeMethod<bool>('checkAccessibility');
    return result ?? false;
  }

  @override
  Future<bool> requestAccessibility() async {
    final result = await _methodChannel.invokeMethod<bool>('requestAccessibility');
    return result ?? false;
  }
}
