import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yap/services/assemblyai/assemblyai_service.dart';
import 'package:yap/services/audio/audio_service.dart';
import 'package:yap/features/recording/recording_service.dart';
import 'package:yap/features/recording/recording_state.dart';

// ---------------------------------------------------------------------------
// Mock AudioService
// ---------------------------------------------------------------------------

class MockAudioService implements AudioService {
  final _audioController = StreamController<Uint8List>.broadcast();
  bool _capturing = false;
  bool startCaptureThrows = false;

  @override
  bool get isCapturing => _capturing;

  @override
  Stream<Uint8List> get audioStream => _audioController.stream;

  @override
  Future<void> startCapture() async {
    if (startCaptureThrows) {
      throw Exception('Mock audio error');
    }
    _capturing = true;
  }

  @override
  Future<void> stopCapture() async {
    _capturing = false;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  void dispose() {
    _audioController.close();
  }
}

// ---------------------------------------------------------------------------
// Mock AssemblyAIService
// ---------------------------------------------------------------------------

class MockAssemblyAIService implements AssemblyAIService {
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();
  bool _active = false;
  final List<String> _finals = [];
  bool startSessionThrows = false;

  @override
  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;

  @override
  bool get isActive => _active;

  @override
  Future<void> startSession({
    required Stream<Uint8List> audioStream,
    required String apiKey,
  }) async {
    if (startSessionThrows) {
      throw Exception('Mock WebSocket error');
    }
    _active = true;
  }

  @override
  Future<String> endSession() async {
    _active = false;
    return _finals.join(' ').trim();
  }

  /// Simulate emitting a transcript segment.
  void emitSegment(TranscriptSegment segment) {
    if (segment.type == TranscriptType.final_) {
      _finals.add(segment.text);
    }
    _transcriptController.add(segment);
  }

  /// Simulate an error on the transcript stream.
  void emitError(Object error) {
    _transcriptController.addError(error);
  }

  void dispose() {
    _transcriptController.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TranscriptSegment _partial(String text) => TranscriptSegment(
      text: text,
      type: TranscriptType.partial,
      audioStart: 0,
      audioEnd: 1,
      receivedAt: DateTime.now(),
    );

TranscriptSegment _final(String text) => TranscriptSegment(
      text: text,
      type: TranscriptType.final_,
      audioStart: 0,
      audioEnd: 1,
      receivedAt: DateTime.now(),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAudioService audioService;
  late MockAssemblyAIService assemblyAIService;

  setUp(() {
    audioService = MockAudioService();
    assemblyAIService = MockAssemblyAIService();
  });

  tearDown(() {
    audioService.dispose();
    assemblyAIService.dispose();
  });

  RecordingServiceImpl createService({String? apiKey = 'test-key'}) {
    return RecordingServiceImpl(
      audioService: audioService,
      assemblyAIService: assemblyAIService,
      apiKey: apiKey,
    );
  }

  group('RecordingServiceImpl', () {
    test('initial state is idle', () {
      final service = createService();
      expect(service.state.status, equals(RecordingStatus.idle));
      service.dispose();
    });

    test('throws NoApiKeyException when API key is null', () async {
      final service = createService(apiKey: null);
      expect(
        () => service.startRecording(),
        throwsA(isA<NoApiKeyException>()),
      );
      service.dispose();
    });

    test('throws NoApiKeyException when API key is empty', () async {
      final service = createService(apiKey: '');
      expect(
        () => service.startRecording(),
        throwsA(isA<NoApiKeyException>()),
      );
      service.dispose();
    });

    test('startRecording transitions to recording state', () async {
      final service = createService();
      final states = <RecordingState>[];
      service.stateStream.listen(states.add);

      await service.startRecording();

      expect(service.state.status, equals(RecordingStatus.recording));
      expect(service.state.startedAt, isNotNull);
      expect(audioService.isCapturing, isTrue);
      expect(assemblyAIService.isActive, isTrue);

      await service.cancelRecording();
      service.dispose();
    });

    test('handles audio capture failure gracefully', () async {
      audioService.startCaptureThrows = true;
      final service = createService();

      await service.startRecording();

      expect(service.state.status, equals(RecordingStatus.error));
      expect(service.state.errorMessage, contains('audio capture'));
      service.dispose();
    });

    test('handles WebSocket connection failure gracefully', () async {
      assemblyAIService.startSessionThrows = true;
      final service = createService();

      await service.startRecording();

      expect(service.state.status, equals(RecordingStatus.error));
      expect(service.state.errorMessage, contains('AssemblyAI'));
      // Audio should have been stopped after AssemblyAI failure.
      expect(audioService.isCapturing, isFalse);
      service.dispose();
    });

    test('builds display transcript from finals + partial', () async {
      final service = createService();
      await service.startRecording();

      assemblyAIService.emitSegment(_final('Hello.'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hello.'));
      expect(service.state.finalTranscript, equals('Hello.'));

      assemblyAIService.emitSegment(_partial('How are'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hello. How are'));
      expect(service.state.finalTranscript, equals('Hello.'));

      assemblyAIService.emitSegment(_final('How are you?'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hello. How are you?'));
      expect(service.state.finalTranscript, equals('Hello. How are you?'));

      await service.cancelRecording();
      service.dispose();
    });

    test('partial replaces previous partial', () async {
      final service = createService();
      await service.startRecording();

      assemblyAIService.emitSegment(_partial('Hel'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hel'));

      assemblyAIService.emitSegment(_partial('Hello'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hello'));

      assemblyAIService.emitSegment(_final('Hello world.'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.currentTranscript, equals('Hello world.'));

      await service.cancelRecording();
      service.dispose();
    });

    test('stopRecording transitions to complete with final transcript',
        () async {
      final service = createService();
      await service.startRecording();

      assemblyAIService.emitSegment(_final('First sentence.'));
      assemblyAIService.emitSegment(_final('Second sentence.'));
      await Future<void>.delayed(Duration.zero);

      await service.stopRecording();

      expect(service.state.status, equals(RecordingStatus.complete));
      expect(
        service.state.finalTranscript,
        equals('First sentence. Second sentence.'),
      );
      expect(audioService.isCapturing, isFalse);
      expect(assemblyAIService.isActive, isFalse);
      service.dispose();
    });

    test('cancelRecording resets to idle', () async {
      final service = createService();
      await service.startRecording();

      assemblyAIService.emitSegment(_final('Some text.'));
      await Future<void>.delayed(Duration.zero);

      await service.cancelRecording();

      expect(service.state.status, equals(RecordingStatus.idle));
      expect(audioService.isCapturing, isFalse);
      service.dispose();
    });

    test('transcript error transitions to error state preserving transcript',
        () async {
      final service = createService();
      await service.startRecording();

      assemblyAIService.emitSegment(_final('Saved text.'));
      await Future<void>.delayed(Duration.zero);

      assemblyAIService.emitError(Exception('WebSocket dropped'));
      await Future<void>.delayed(Duration.zero);

      expect(service.state.status, equals(RecordingStatus.error));
      expect(service.state.finalTranscript, equals('Saved text.'));
      expect(service.state.errorMessage, contains('WebSocket dropped'));
      service.dispose();
    });

    test('stopRecording is a no-op when not recording', () async {
      final service = createService();

      // Should not throw or change state.
      await service.stopRecording();

      expect(service.state.status, equals(RecordingStatus.idle));
      service.dispose();
    });

    test('startRecording is a no-op when already recording', () async {
      final service = createService();
      await service.startRecording();

      // Second call should be ignored.
      await service.startRecording();

      expect(service.state.status, equals(RecordingStatus.recording));

      await service.cancelRecording();
      service.dispose();
    });

    test('stateStream emits state changes', () async {
      final service = createService();
      final statuses = <RecordingStatus>[];
      service.stateStream.listen((s) => statuses.add(s.status));

      await service.startRecording();
      await Future<void>.delayed(Duration.zero);

      assemblyAIService.emitSegment(_final('Hi.'));
      await Future<void>.delayed(Duration.zero);

      await service.stopRecording();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, contains(RecordingStatus.recording));
      expect(statuses, contains(RecordingStatus.stopping));
      expect(statuses, contains(RecordingStatus.complete));

      service.dispose();
    });
  });
}
