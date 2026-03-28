import 'dart:typed_data';

/// Abstract interface for microphone audio capture.
///
/// Audio is captured as raw PCM: 16kHz, mono, 16-bit signed little-endian.
/// Chunks are ~100 ms of audio (~3 200 bytes).
abstract class AudioService {
  /// Stream of raw PCM audio chunks (16kHz, mono, 16-bit).
  /// Chunks should be ~100ms of audio (~3200 bytes at 16kHz/16-bit/mono).
  Stream<Uint8List> get audioStream;

  /// Start capturing audio from the default microphone.
  /// Throws if microphone permission is not granted.
  Future<void> startCapture();

  /// Stop capturing.
  Future<void> stopCapture();

  /// Whether audio is currently being captured.
  bool get isCapturing;

  /// Check if microphone permission is granted.
  Future<bool> hasPermission();

  /// Request microphone permission. Returns true if granted.
  Future<bool> requestPermission();
}
