import 'dart:typed_data';

/// Represents an available audio input device.
class AudioDevice {
  final String id;
  final String name;
  final bool isDefault;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.isDefault,
  });
}

/// Abstract interface for microphone audio capture.
///
/// Audio is captured as raw PCM: 16kHz, mono, 16-bit signed little-endian.
abstract class AudioService {
  /// Stream of raw PCM audio chunks (16kHz, mono, 16-bit).
  Stream<Uint8List> get audioStream;

  /// Stream of audio level values (0.0 to 1.0) for visual feedback.
  Stream<double> get audioLevelStream;

  /// Start capturing audio from the specified device (or default if null).
  Future<void> startCapture({String? deviceId});

  /// Stop capturing.
  Future<void> stopCapture();

  /// Whether audio is currently being captured.
  bool get isCapturing;

  /// List available audio input devices.
  Future<List<AudioDevice>> listDevices();

  /// Check if microphone permission is granted.
  Future<bool> hasPermission();

  /// Request microphone permission. Returns true if granted.
  Future<bool> requestPermission();
}
