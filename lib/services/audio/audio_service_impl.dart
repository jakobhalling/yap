import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'audio_service.dart';

/// Platform-channel backed implementation of [AudioService].
///
/// Communicates with native code over:
/// - `MethodChannel('com.yap.audio')` for start / stop / permissions
/// - `EventChannel('com.yap.audio/samples')` for PCM audio chunks
class AudioServiceImpl implements AudioService {
  AudioServiceImpl({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('com.yap.audio'),
        _eventChannel =
            eventChannel ?? const EventChannel('com.yap.audio/samples');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamController<Uint8List>? _controller;
  StreamSubscription<dynamic>? _eventSubscription;
  bool _isCapturing = false;

  @override
  Stream<Uint8List> get audioStream {
    _controller ??= StreamController<Uint8List>.broadcast();
    return _controller!.stream;
  }

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> startCapture() async {
    _controller ??= StreamController<Uint8List>.broadcast();

    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is Uint8List) {
        _controller?.add(data);
      }
    }, onError: (Object error) {
      _controller?.addError(error);
    });

    await _methodChannel.invokeMethod<void>('startCapture');
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    await _methodChannel.invokeMethod<void>('stopCapture');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _isCapturing = false;
  }

  @override
  Future<bool> hasPermission() async {
    final result =
        await _methodChannel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    final result =
        await _methodChannel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }
}
