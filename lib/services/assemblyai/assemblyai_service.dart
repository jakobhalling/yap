import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../log_service.dart';
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
  String _latestPartial = '';

  Completer<void>? _terminationCompleter;
  bool _isActive = false;
  int _audioChunksSent = 0;
  int _messagesReceived = 0;

  /// Buffer for accumulating small audio chunks before sending.
  /// AssemblyAI requires 50-1000ms per message. At 16kHz/16-bit/mono,
  /// 100ms = 3200 bytes.
  final _audioBuffer = BytesBuilder(copy: false);
  static const int _minChunkBytes = 3200; // 100ms at 16kHz/16-bit/mono

  @override
  Stream<TranscriptSegment> get transcriptStream => _transcriptController.stream;

  @override
  bool get isActive => _isActive;

  /// Request a temporary authentication token from AssemblyAI REST API (v3).
  Future<String> _getTemporaryToken(String apiKey) async {
    final dio = Dio();
    try {
      final response = await dio.get(
        AssemblyAIConfig.tokenUrl,
        queryParameters: {'expires_in_seconds': 600},
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );
      final token = response.data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('AssemblyAI returned empty token');
      }
      return token;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw Exception(
          'Failed to get AssemblyAI token: HTTP $status — $body');
    }
  }

  @override
  Future<void> startSession({
    required Stream<Uint8List> audioStream,
    required String apiKey,
  }) async {
    if (_isActive) {
      throw StateError('A session is already active. Call endSession() first.');
    }

    _finalSegments.clear();
    _latestPartial = '';
    _terminationCompleter = null;
    _audioChunksSent = 0;
    _messagesReceived = 0;

    // Step 1: Get a temporary token via REST API.
    Log.i('AssemblyAI', 'Fetching temporary token');
    final tempToken = await _getTemporaryToken(apiKey);
    Log.i('AssemblyAI', 'Token acquired, connecting WebSocket');

    // Step 2: Connect WebSocket with the temporary token.
    final wsUrl = AssemblyAIConfig.buildWsUrl(tempToken);
    Log.d('AssemblyAI', 'WebSocket URL: ${wsUrl.replaceAll(RegExp(r'token=[^&]+'), 'token=***')}');
    final uri = Uri.parse(wsUrl);

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
    Log.i('AssemblyAI', 'WebSocket connected, session started');

    // Listen to incoming messages from AssemblyAI.
    _wsSubscription = _channel!.stream.listen(
      _onMessage,
      onError: _onWsError,
      onDone: _onWsDone,
    );

    // Forward audio chunks to the WebSocket as raw binary (v3 format).
    // Buffer small chunks to meet AssemblyAI's 50-1000ms requirement.
    _audioBuffer.clear();
    int _totalBytesReceived = 0;
    _audioSubscription = audioStream.listen(
      (Uint8List chunk) {
        if (!_isActive || _channel == null) return;
        _totalBytesReceived += chunk.length;
        _audioBuffer.add(chunk);
        if (_audioBuffer.length >= _minChunkBytes) {
          _audioChunksSent++;
          final bytes = _audioBuffer.takeBytes();
          _channel!.sink.add(bytes);
          if (_audioChunksSent == 1) {
            Log.d('AssemblyAI', 'First audio chunk sent: ${bytes.length} bytes (total received from mic: $_totalBytesReceived bytes)');
          }
        }
      },
      onError: (Object error) {
        _transcriptController.addError(error);
      },
    );
  }

  @override
  Future<String> endSession() async {
    Log.i('AssemblyAI', 'Ending session (chunks sent: $_audioChunksSent, messages received: $_messagesReceived)');
    if (!_isActive || _channel == null) {
      return _finalSegments.join(' ').trim();
    }

    // Flush any remaining buffered audio.
    if (_audioBuffer.length > 0) {
      _channel!.sink.add(_audioBuffer.takeBytes());
    }

    // Send the v3 termination request.
    _terminationCompleter = Completer<void>();
    _channel!.sink.add(jsonEncode({'type': 'Terminate'}));

    // Wait for the Termination response (with a timeout).
    // AssemblyAI may still send final transcript segments before the
    // Termination ack, so this also gives time for those to arrive.
    try {
      await _terminationCompleter!.future
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Timed out waiting — close anyway.
    }

    // Preserve the last partial transcript that was never finalized.
    // This happens when the user stops recording mid-sentence — AssemblyAI
    // only sends end_of_turn after detecting a speech pause, so the last
    // words remain as a partial. Capture them so they aren't lost.
    if (_latestPartial.isNotEmpty) {
      _finalSegments.add(_latestPartial);
      _latestPartial = '';
    }

    await _cleanup();
    return _finalSegments.join(' ').trim();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    _messagesReceived++;
    if (raw is! String) {
      Log.d('AssemblyAI', 'Received non-string message (${raw.runtimeType})');
      return;
    }

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      Log.w('AssemblyAI', 'Failed to parse message: $e');
      return;
    }

    final message = AssemblyAIMessage.fromJson(json);
    Log.d('AssemblyAI', 'Message #$_messagesReceived: type=${message.type}, transcript="${message.transcript ?? ""}", endOfTurn=${message.endOfTurn}');

    if (message.isTermination) {
      Log.i('AssemblyAI', 'Termination acknowledged');
      _terminationCompleter?.complete();
      return;
    }

    if (message.isBegin) {
      Log.i('AssemblyAI', 'Session confirmed');
      return;
    }

    if (message.isError) {
      Log.e('AssemblyAI', 'Server error: ${message.error ?? "unknown"}');
      _transcriptController.addError(
        Exception('AssemblyAI error: ${message.error ?? "unknown"}'),
      );
      return;
    }

    // v3 uses Turn messages with end_of_turn for partial/final.
    if (message.isTurn) {
      final text = message.transcript ?? '';
      if (text.isEmpty) return;

      final isFinal = message.isFinalTurn;
      final segment = TranscriptSegment(
        text: text,
        type: isFinal ? TranscriptType.final_ : TranscriptType.partial,
        audioStart: 0,
        audioEnd: 0,
        receivedAt: DateTime.now(),
      );

      if (isFinal) {
        _finalSegments.add(text);
        _latestPartial = '';
      } else {
        _latestPartial = text;
      }

      _transcriptController.add(segment);
    }
  }

  void _onWsError(Object error) {
    Log.e('AssemblyAI', 'WebSocket error', error);
    _transcriptController.addError(error);
    _cleanup();
  }

  void _onWsDone() {
    // WebSocket closed (could be expected or unexpected).
    if (_isActive && _terminationCompleter == null) {
      final closeCode = _channel?.closeCode;
      final closeReason = _channel?.closeReason;
      _transcriptController.addError(
        Exception('WebSocket closed unexpectedly '
            '(code: $closeCode, reason: $closeReason, '
            'audio chunks sent: $_audioChunksSent, '
            'messages received: $_messagesReceived)'),
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

