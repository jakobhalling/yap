import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'assemblyai_config.dart';
import 'assemblyai_models.dart';

// ---------------------------------------------------------------------------
// Transcript segment — the public output of the service
// ---------------------------------------------------------------------------

/// Whether a transcript segment is a partial (interim) or final (committed).
enum TranscriptType { partial, final_ }

/// A single transcript segment emitted by [AssemblyAIService].
class TranscriptSegment {
  final String text;
  final TranscriptType type;

  /// Seconds from the start of the audio stream.
  final double audioStart;

  /// Seconds from the start of the audio stream.
  final double audioEnd;

  final DateTime receivedAt;

  const TranscriptSegment({
    required this.text,
    required this.type,
    required this.audioStart,
    required this.audioEnd,
    required this.receivedAt,
  });

  @override
  String toString() =>
      'TranscriptSegment(type=$type, text="$text", '
      'start=${audioStart}s, end=${audioEnd}s)';
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Service for real-time speech-to-text via AssemblyAI's WebSocket API.
abstract class AssemblyAIService {
  /// Stream of transcript segments (both partial and final).
  Stream<TranscriptSegment> get transcriptStream;

  /// Connect to AssemblyAI and begin streaming audio.
  Future<void> startSession({
    required Stream<Uint8List> audioStream,
    required String apiKey,
  });

  /// Gracefully close the session.
  /// Returns the final combined transcript (all final segments joined).
  Future<String> endSession();

  /// Whether a WebSocket session is currently active.
  bool get isActive;
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

/// Default implementation that talks to the real AssemblyAI WebSocket.
///
/// The [channelFactory] parameter exists so tests can inject a mock
/// WebSocket channel. In production, leave it null to use the default
/// [WebSocketChannel.connect].
class AssemblyAIServiceImpl implements AssemblyAIService {
  AssemblyAIServiceImpl({this.channelFactory});

  /// Optional factory for creating WebSocket channels. Used for testing.
  final WebSocketChannel Function(Uri uri)? channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;

  final _transcriptController = StreamController<TranscriptSegment>.broadcast();
  final List<String> _finalSegments = [];

  Completer<void>? _terminationCompleter;
  bool _isActive = false;

  @override
  Stream<TranscriptSegment> get transcriptStream => _transcriptController.stream;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> startSession({
    required Stream<Uint8List> audioStream,
    required String apiKey,
  }) async {
    if (_isActive) {
      throw StateError('A session is already active. Call endSession() first.');
    }

    _finalSegments.clear();
    _terminationCompleter = null;

    final uri = Uri.parse(AssemblyAIConfig.buildWsUrl(apiKey));

    try {
      _channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);

      // Wait for the WebSocket to be ready (throws on failure).
      await _channel!.ready;
    } catch (e) {
      _cleanup();
      rethrow;
    }

    _isActive = true;

    // Listen to incoming messages from AssemblyAI.
    _wsSubscription = _channel!.stream.listen(
      _onMessage,
      onError: _onWsError,
      onDone: _onWsDone,
    );

    // Forward audio chunks to the WebSocket as base64-encoded JSON.
    _audioSubscription = audioStream.listen(
      (Uint8List chunk) {
        if (!_isActive || _channel == null) return;
        final b64 = base64Encode(chunk);
        _channel!.sink.add(jsonEncode({'audio_data': b64}));
      },
      onError: (Object error) {
        // Audio stream errored — propagate as a transcript stream error.
        _transcriptController.addError(error);
      },
    );
  }

  @override
  Future<String> endSession() async {
    if (!_isActive || _channel == null) {
      return _finalSegments.join(' ').trim();
    }

    // Send the termination request.
    _terminationCompleter = Completer<void>();
    _channel!.sink.add(jsonEncode({'terminate_session': true}));

    // Wait for the SessionTerminated response (with a timeout).
    try {
      await _terminationCompleter!.future
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Timed out waiting — close anyway.
    }

    await _cleanup();
    return _finalSegments.join(' ').trim();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    if (raw is! String) return;

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final message = AssemblyAIMessage.fromJson(json);

    if (message.isSessionTerminated) {
      _terminationCompleter?.complete();
      return;
    }

    if (message.isSessionBegins) {
      // Session confirmed — nothing to emit yet.
      return;
    }

    if (message.messageType == AssemblyAIMessageTypes.error) {
      _transcriptController.addError(
        Exception('AssemblyAI error: ${message.error ?? "unknown"}'),
      );
      return;
    }

    if (message.isPartial || message.isFinal) {
      final text = message.text ?? '';
      // Only emit non-empty segments.
      if (text.isEmpty) return;

      final segment = TranscriptSegment(
        text: text,
        type: message.isPartial ? TranscriptType.partial : TranscriptType.final_,
        audioStart: (message.audioStart ?? 0) / 1000.0,
        audioEnd: (message.audioEnd ?? 0) / 1000.0,
        receivedAt: DateTime.now(),
      );

      if (message.isFinal) {
        _finalSegments.add(text);
      }

      _transcriptController.add(segment);
    }
  }

  void _onWsError(Object error) {
    _transcriptController.addError(error);
    _cleanup();
  }

  void _onWsDone() {
    // WebSocket closed (could be expected or unexpected).
    if (_isActive && _terminationCompleter == null) {
      // Unexpected closure.
      _transcriptController.addError(
        Exception('WebSocket closed unexpectedly'),
      );
    }
    _terminationCompleter?.complete();
    _cleanup();
  }

  Future<void> _cleanup() async {
    _isActive = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Ignore errors when closing the sink.
    }
    _channel = null;
  }
}

