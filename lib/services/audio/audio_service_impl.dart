import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:yap/services/log_service.dart';

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
    Log.i('Audio',
        'Starting capture${deviceId != null ? " (device: $deviceId)" : " (default device)"}');
    _controller ??= StreamController<Uint8List>.broadcast();
    _levelController ??= StreamController<double>.broadcast();

    bool receivedAudioData = false;
    bool receivedLevel = false;

    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is Uint8List) {
        if (!receivedAudioData) {
          receivedAudioData = true;
          Log.i('Audio', 'First audio data received (${data.length} bytes)');
        }
        _controller?.add(data);
      }
    }, onError: (Object error) {
      Log.e('Audio', 'Audio stream error', error);
      _controller?.addError(error);
    });

    _levelSubscription =
        _levelChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is double) {
        if (!receivedLevel) {
          receivedLevel = true;
          Log.i('Audio', 'Audio level stream active (level: ${data.toStringAsFixed(3)})');
        }
        _levelController?.add(data);
      }
    });

    final args = <String, dynamic>{};
    if (deviceId != null && deviceId.isNotEmpty) {
      args['deviceId'] = deviceId;
    }
    try {
      await _methodChannel.invokeMethod<void>('startCapture', args);
      Log.i('Audio', 'Capture started via platform channel');
    } catch (e) {
      Log.e('Audio', 'Platform startCapture failed', e);
      rethrow;
    }
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    Log.i('Audio', 'Stopping capture');
    await _methodChannel.invokeMethod<void>('stopCapture');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    _isCapturing = false;
    Log.i('Audio', 'Capture stopped');
  }

  @override
  Future<List<AudioDevice>> listDevices() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('listDevices');
    if (result == null) {
      Log.w('Audio', 'listDevices returned null');
      return [];
    }
    final devices = result.map((d) {
      final map = Map<String, dynamic>.from(d as Map);
      return AudioDevice(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown',
        isDefault: map['isDefault'] as bool? ?? false,
      );
    }).toList();
    Log.i('Audio',
        'Found ${devices.length} device(s): ${devices.map((d) => '"${d.name}"${d.isDefault ? " [default]" : ""}').join(", ")}');
    return devices;
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
