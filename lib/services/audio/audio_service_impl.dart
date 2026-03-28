import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'audio_service.dart';

/// Platform-channel backed implementation of [AudioService].
class AudioServiceImpl implements AudioService {
  AudioServiceImpl({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    EventChannel? levelChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('com.yap.audio'),
        _eventChannel =
            eventChannel ?? const EventChannel('com.yap.audio/samples'),
        _levelChannel =
            levelChannel ?? const EventChannel('com.yap.audio/level');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final EventChannel _levelChannel;

  StreamController<Uint8List>? _controller;
  StreamController<double>? _levelController;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _levelSubscription;
  bool _isCapturing = false;

  @override
  Stream<Uint8List> get audioStream {
    _controller ??= StreamController<Uint8List>.broadcast();
    return _controller!.stream;
  }

  @override
  Stream<double> get audioLevelStream {
    _levelController ??= StreamController<double>.broadcast();
    return _levelController!.stream;
  }

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> startCapture({String? deviceId}) async {
    _controller ??= StreamController<Uint8List>.broadcast();
    _levelController ??= StreamController<double>.broadcast();

    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is Uint8List) {
        _controller?.add(data);
      }
    }, onError: (Object error) {
      _controller?.addError(error);
    });

    _levelSubscription =
        _levelChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is double) {
        _levelController?.add(data);
      }
    });

    final args = <String, dynamic>{};
    if (deviceId != null && deviceId.isNotEmpty) {
      args['deviceId'] = deviceId;
    }
    await _methodChannel.invokeMethod<void>('startCapture', args);
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    await _methodChannel.invokeMethod<void>('stopCapture');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    _isCapturing = false;
  }

  @override
  Future<List<AudioDevice>> listDevices() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('listDevices');
    if (result == null) return [];
    return result.map((d) {
      final map = Map<String, dynamic>.from(d as Map);
      return AudioDevice(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown',
        isDefault: map['isDefault'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<bool> hasPermission() async {
    final result = await _methodChannel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    final result = await _methodChannel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }
}
