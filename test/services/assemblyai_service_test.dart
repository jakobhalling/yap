import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:yap/services/assemblyai/assemblyai_service.dart';
import 'package:yap/services/assemblyai/assemblyai_models.dart';

// ---------------------------------------------------------------------------
// Mock WebSocket channel that simulates AssemblyAI responses
// ---------------------------------------------------------------------------

class MockWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];
  final StreamController<void> _closeController = StreamController<void>();
  bool closed = false;

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_closeController.isClosed) {
      _closeController.close();
    }
  }

  @override
  Future get done => _closeController.done;
}

class MockWebSocketChannel implements WebSocketChannel {
  MockWebSocketChannel() : sink = MockWebSocketSink();

  final StreamController<dynamic> _incomingController =
      StreamController<dynamic>.broadcast();

  @override
  final MockWebSocketSink sink;

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();

  /// Simulate a message from AssemblyAI.
  void simulateMessage(Map<String, dynamic> json) {
    _incomingController.add(jsonEncode(json));
  }

  /// Simulate the server closing the connection.
  void simulateClose() {
    _incomingController.close();
  }

  @override
  void pipe(StreamChannel<dynamic> other) {}

  @override
  StreamChannel<S> cast<S>() => throw UnimplementedError();

  @override
  StreamChannel<dynamic> changeSink(
          StreamSink<dynamic> Function(StreamSink<dynamic>) change) =>
      throw UnimplementedError();

  @override
  StreamChannel<dynamic> changeStream(
          Stream<dynamic> Function(Stream<dynamic>) change) =>
      throw UnimplementedError();

  @override
  StreamChannel<S> transform<S>(
          StreamChannelTransformer<S, dynamic> transformer) =>
      throw UnimplementedError();

  @override
  StreamChannel<S> transformSink<S>(
          StreamSinkTransformer<S, dynamic> transformer) =>
      throw UnimplementedError();

  @override
  StreamChannel<S> transformStream<S>(
          StreamTransformer<dynamic, S> transformer) =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockWebSocketChannel mockChannel;
  late AssemblyAIServiceImpl service;
  late StreamController<Uint8List> audioController;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    service = AssemblyAIServiceImpl(
      channelFactory: (_) => mockChannel,
    );
    audioController = StreamController<Uint8List>.broadcast();
  });

  tearDown(() async {
    if (service.isActive) {
      // Force cleanup to avoid leaks
      mockChannel.simulateMessage({'message_type': 'SessionTerminated'});
      await service.endSession();
    }
    await audioController.close();
  });

  group('AssemblyAIServiceImpl', () {
    test('startSession sets isActive to true', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      expect(service.isActive, isTrue);
    });

    test('startSession throws if already active', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      expect(
        () => service.startSession(
          audioStream: audioController.stream,
          apiKey: 'test-key-2',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('sends audio data as base64-encoded JSON', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      audioController.add(testData);

      // Allow microtask queue to flush.
      await Future<void>.delayed(Duration.zero);

      expect(mockChannel.sink.sentMessages, hasLength(1));
      final sent = jsonDecode(mockChannel.sink.sentMessages.first as String)
          as Map<String, dynamic>;
      expect(sent['audio_data'], equals(base64Encode(testData)));
    });

    test('emits partial transcript segments', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final segments = <TranscriptSegment>[];
      service.transcriptStream.listen(segments.add);

      mockChannel.simulateMessage({
        'message_type': 'PartialTranscript',
        'text': 'hello world',
        'audio_start': 0,
        'audio_end': 1440,
        'words': [
          {'text': 'hello', 'start': 0, 'end': 700, 'confidence': 0.95},
          {'text': 'world', 'start': 720, 'end': 1440, 'confidence': 0.92},
        ],
      });

      await Future<void>.delayed(Duration.zero);

      expect(segments, hasLength(1));
      expect(segments.first.text, equals('hello world'));
      expect(segments.first.type, equals(TranscriptType.partial));
      expect(segments.first.audioStart, closeTo(0.0, 0.001));
      expect(segments.first.audioEnd, closeTo(1.44, 0.001));
    });

    test('emits final transcript segments', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final segments = <TranscriptSegment>[];
      service.transcriptStream.listen(segments.add);

      mockChannel.simulateMessage({
        'message_type': 'FinalTranscript',
        'text': 'hello world',
        'audio_start': 0,
        'audio_end': 1440,
        'words': [],
      });

      await Future<void>.delayed(Duration.zero);

      expect(segments, hasLength(1));
      expect(segments.first.type, equals(TranscriptType.final_));
    });

    test('ignores empty text segments', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final segments = <TranscriptSegment>[];
      service.transcriptStream.listen(segments.add);

      mockChannel.simulateMessage({
        'message_type': 'PartialTranscript',
        'text': '',
        'audio_start': 0,
        'audio_end': 0,
      });

      await Future<void>.delayed(Duration.zero);

      expect(segments, isEmpty);
    });

    test('endSession sends terminate_session and returns combined finals',
        () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      // Simulate two final segments.
      mockChannel.simulateMessage({
        'message_type': 'FinalTranscript',
        'text': 'Hello.',
        'audio_start': 0,
        'audio_end': 1000,
      });
      mockChannel.simulateMessage({
        'message_type': 'FinalTranscript',
        'text': 'How are you?',
        'audio_start': 1000,
        'audio_end': 2500,
      });

      await Future<void>.delayed(Duration.zero);

      // Schedule the SessionTerminated response.
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        mockChannel.simulateMessage({'message_type': 'SessionTerminated'});
      });

      final result = await service.endSession();

      expect(result, equals('Hello. How are you?'));
      expect(service.isActive, isFalse);

      // Verify terminate_session was sent.
      final terminateMsg = mockChannel.sink.sentMessages.last as String;
      final parsed = jsonDecode(terminateMsg) as Map<String, dynamic>;
      expect(parsed['terminate_session'], isTrue);
    });

    test('handles SessionBegins message gracefully', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final segments = <TranscriptSegment>[];
      service.transcriptStream.listen(segments.add);

      mockChannel.simulateMessage({
        'message_type': 'SessionBegins',
        'session_id': 'abc-123',
      });

      await Future<void>.delayed(Duration.zero);

      // No transcript segment emitted for SessionBegins.
      expect(segments, isEmpty);
    });

    test('emits error on unexpected WebSocket closure', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final errors = <Object>[];
      service.transcriptStream.listen((_) {}, onError: errors.add);

      mockChannel.simulateClose();

      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first.toString(), contains('unexpectedly'));
    });

    test('emits error on AssemblyAI error message', () async {
      await service.startSession(
        audioStream: audioController.stream,
        apiKey: 'test-key',
      );

      final errors = <Object>[];
      service.transcriptStream.listen((_) {}, onError: errors.add);

      mockChannel.simulateMessage({
        'message_type': 'error',
        'error': 'Bad request',
      });

      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first.toString(), contains('Bad request'));
    });
  });

  group('AssemblyAIMessage', () {
    test('fromJson parses partial transcript', () {
      final msg = AssemblyAIMessage.fromJson({
        'message_type': 'PartialTranscript',
        'text': 'hello',
        'audio_start': 0,
        'audio_end': 500,
        'words': [
          {'text': 'hello', 'start': 0, 'end': 500, 'confidence': 0.99}
        ],
      });

      expect(msg.isPartial, isTrue);
      expect(msg.isFinal, isFalse);
      expect(msg.text, equals('hello'));
      expect(msg.words, hasLength(1));
      expect(msg.words!.first.confidence, closeTo(0.99, 0.001));
    });

    test('fromJson parses final transcript', () {
      final msg = AssemblyAIMessage.fromJson({
        'message_type': 'FinalTranscript',
        'text': 'hello world',
        'audio_start': 0,
        'audio_end': 1440,
      });

      expect(msg.isFinal, isTrue);
      expect(msg.isPartial, isFalse);
      expect(msg.isSessionTerminated, isFalse);
    });

    test('fromJson parses session terminated', () {
      final msg = AssemblyAIMessage.fromJson({
        'message_type': 'SessionTerminated',
      });

      expect(msg.isSessionTerminated, isTrue);
    });

    test('fromJson handles missing fields gracefully', () {
      final msg = AssemblyAIMessage.fromJson({
        'message_type': 'PartialTranscript',
      });

      expect(msg.text, isNull);
      expect(msg.audioStart, isNull);
      expect(msg.words, isNull);
    });
  });
}
