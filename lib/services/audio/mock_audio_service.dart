import 'dart:async';
import 'dart:typed_data';

import 'audio_service.dart';

/// Mock implementation of [AudioService] for use in tests.
///
/// Call [pushAudioChunk] to manually emit audio data on the stream.
class MockAudioService implements AudioService {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  bool _isCapturing = false;
  bool _hasPermission = true;

  @override
  Stream<Uint8List> get audioStream => _controller.stream;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> startCapture() async {
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
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<bool> requestPermission() async => _hasPermission;

  /// Set whether the mock reports microphone permission as granted.
  set permissionGranted(bool value) => _hasPermission = value;

  /// Push a chunk of audio data onto the stream for testing.
  void pushAudioChunk(Uint8List data) {
    _controller.add(data);
  }

  /// Dispose the underlying stream controller.
  void dispose() {
    _controller.close();
  }
}
