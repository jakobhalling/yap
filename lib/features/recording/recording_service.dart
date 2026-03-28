import 'dart:async';

import 'package:yap/services/assemblyai/assemblyai_service.dart';
import 'package:yap/services/audio/audio_service.dart';

import 'recording_state.dart';

// ---------------------------------------------------------------------------
// Custom exceptions
// ---------------------------------------------------------------------------

/// Thrown when a recording is started without a configured AssemblyAI API key.
class NoApiKeyException implements Exception {
  final String message;
  const NoApiKeyException([this.message = 'AssemblyAI API key is not configured.']);
  @override
  String toString() => 'NoApiKeyException: $message';
}

/// Thrown when microphone permission has not been granted.
class MicrophonePermissionException implements Exception {
  final String message;
  const MicrophonePermissionException(
      [this.message = 'Microphone permission is required to record.']);
  @override
  String toString() => 'MicrophonePermissionException: $message';
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Orchestrates the full recording lifecycle:
/// hotkey → audio capture → transcription → final transcript.
abstract class RecordingService {
  /// Current state snapshot.
  RecordingState get state;

  /// Stream of state changes.
  Stream<RecordingState> get stateStream;

  /// Start a new recording session.
  Future<void> startRecording();

  /// Stop the current session and wait for the final transcript.
  Future<void> stopRecording();

  /// Cancel and discard the current session.
  Future<void> cancelRecording();

  /// Release resources.
  void dispose();
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

/// Default implementation of [RecordingService].
///
/// Coordinates [AudioService] and [AssemblyAIService] to produce a live
/// transcript while recording.
class RecordingServiceImpl implements RecordingService {
  RecordingServiceImpl({
    required this.audioService,
    required this.assemblyAIService,
    required this.apiKey,
  });

  final AudioService audioService;
  final AssemblyAIService assemblyAIService;
  final String? apiKey;

  /// Maximum recording duration before auto-stop.
  static const Duration maxDuration = Duration(minutes: 30);

  // -----------------------------------------------------------------------
  // State management
  // -----------------------------------------------------------------------

  RecordingState _state = const RecordingState();
  final _stateController = StreamController<RecordingState>.broadcast();

  @override
  RecordingState get state => _state;

  @override
  Stream<RecordingState> get stateStream => _stateController.stream;

  void _emit(RecordingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // -----------------------------------------------------------------------
  // Internal bookkeeping
  // -----------------------------------------------------------------------

  final List<String> _finalSegments = [];
  String _latestPartial = '';
  Timer? _elapsedTimer;
  Timer? _maxDurationTimer;
  StreamSubscription<TranscriptSegment>? _transcriptSub;

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  @override
  Future<void> startRecording() async {
    if (_state.status == RecordingStatus.recording ||
        _state.status == RecordingStatus.stopping) {
      return; // Already in progress.
    }

    // Validate API key.
    final key = apiKey;
    if (key == null || key.isEmpty) {
      throw const NoApiKeyException();
    }

    // Reset bookkeeping.
    _finalSegments.clear();
    _latestPartial = '';

    final now = DateTime.now();
    _emit(RecordingState(
      status: RecordingStatus.recording,
      startedAt: now,
    ));

    try {
      // Start audio capture.
      await audioService.startCapture();
    } catch (e) {
      _emit(RecordingState(
        status: RecordingStatus.error,
        errorMessage: 'Failed to start audio capture: $e',
      ));
      return;
    }

    try {
      // Connect to AssemblyAI.
      await assemblyAIService.startSession(
        audioStream: audioService.audioStream,
        apiKey: key,
      );
    } catch (e) {
      // Clean up audio since transcription failed to start.
      await audioService.stopCapture();
      _emit(RecordingState(
        status: RecordingStatus.error,
        errorMessage: 'Failed to connect to AssemblyAI: $e',
      ));
      return;
    }

    // Listen to transcript segments.
    _transcriptSub = assemblyAIService.transcriptStream.listen(
      _onTranscriptSegment,
      onError: _onTranscriptError,
    );

    // Elapsed time ticker (every second).
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.status != RecordingStatus.recording) return;
      final elapsed = DateTime.now().difference(_state.startedAt!);
      _emit(_state.copyWith(elapsed: elapsed));
    });

    // Max duration auto-stop.
    _maxDurationTimer = Timer(maxDuration, () {
      if (_state.status == RecordingStatus.recording) {
        stopRecording();
      }
    });
  }

  @override
  Future<void> stopRecording() async {
    if (_state.status != RecordingStatus.recording) return;

    _emit(_state.copyWith(status: RecordingStatus.stopping));

    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    // Stop audio capture first so no more data is sent.
    try {
      await audioService.stopCapture();
    } catch (_) {
      // Best-effort; continue to get the transcript.
    }

    // End the AssemblyAI session and retrieve the final transcript.
    String finalText;
    try {
      finalText = await assemblyAIService.endSession();
    } catch (e) {
      finalText = _buildFinalTranscript();
    }

    await _transcriptSub?.cancel();
    _transcriptSub = null;

    _emit(RecordingState(
      status: RecordingStatus.complete,
      currentTranscript: finalText,
      finalTranscript: finalText,
      elapsed: _state.elapsed,
      startedAt: _state.startedAt,
    ));
  }

  @override
  Future<void> cancelRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _transcriptSub?.cancel();
    _transcriptSub = null;

    if (audioService.isCapturing) {
      try {
        await audioService.stopCapture();
      } catch (_) {}
    }
    if (assemblyAIService.isActive) {
      try {
        await assemblyAIService.endSession();
      } catch (_) {}
    }

    _emit(const RecordingState(status: RecordingStatus.idle));
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _maxDurationTimer?.cancel();
    _transcriptSub?.cancel();
    _stateController.close();
  }

  // -----------------------------------------------------------------------
  // Internal handlers
  // -----------------------------------------------------------------------

  void _onTranscriptSegment(TranscriptSegment segment) {
    if (segment.type == TranscriptType.final_) {
      _finalSegments.add(segment.text);
      _latestPartial = '';
    } else {
      _latestPartial = segment.text;
    }

    final display = _buildDisplayTranscript();
    final finals = _buildFinalTranscript();

    _emit(_state.copyWith(
      currentTranscript: display,
      finalTranscript: finals,
    ));
  }

  void _onTranscriptError(Object error) {
    // Preserve whatever transcript we already have.
    _elapsedTimer?.cancel();
    _maxDurationTimer?.cancel();

    _emit(RecordingState(
      status: RecordingStatus.error,
      currentTranscript: _state.currentTranscript,
      finalTranscript: _buildFinalTranscript(),
      elapsed: _state.elapsed,
      errorMessage: error.toString(),
      startedAt: _state.startedAt,
    ));
  }

  String _buildFinalTranscript() => _finalSegments.join(' ').trim();

  String _buildDisplayTranscript() {
    final finals = _buildFinalTranscript();
    if (_latestPartial.isEmpty) return finals;
    if (finals.isEmpty) return _latestPartial;
    return '$finals $_latestPartial';
  }
}
