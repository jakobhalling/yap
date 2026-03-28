import 'dart:async';
import 'dart:typed_data';

import 'audio_service.dart';

/// Mock implementation of [AudioService] for use in tests.
class MockAudioService implements AudioService {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _levelController =
      StreamController<double>.broadcast();

  bool _isCapturing = false;
  bool _hasPermission = true;

  @override
  Stream<Uint8List> get audioStream => _controller.stream;

  @override
  Stream<double> get audioLevelStream => _levelController.stream;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> startCapture({String? deviceId}) async {
    if (!_hasPermission) {
      throw Exception('Microphone permission not granted');
    }
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    _isCapturing = false;
  }

  @override
  Future<List<AudioDevice>> listDevices() async {
    return [
      const AudioDevice(id: 'mock-1', name: 'Mock Microphone', isDefault: true),
    ];
  }

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<bool> requestPermission() async => _hasPermission;

  set permissionGranted(bool value) => _hasPermission = value;

  void pushAudioChunk(Uint8List data) {
    _controller.add(data);
  }

  void dispose() {
    _controller.close();
    _levelController.close();
  }
}
