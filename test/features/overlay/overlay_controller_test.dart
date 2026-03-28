import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yap/features/overlay/overlay_controller.dart';
import 'package:yap/features/overlay/overlay_window.dart';
import 'package:yap/features/processing/processing_service.dart';
import 'package:yap/features/processing/processing_state.dart';
import 'package:yap/features/recording/recording_service.dart';
import 'package:yap/features/recording/recording_state.dart';
import 'package:yap/features/history/history_service.dart';
import 'package:yap/features/settings/settings_service.dart';
import 'package:yap/services/hotkey/hotkey_service.dart';
import 'package:yap/services/paste/paste_service.dart';
import 'package:yap/shared/prompts/default_prompts.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockHotkeyService implements HotkeyService {
  final _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onDoubleTap => _controller.stream;
  void emitDoubleTap() => _controller.add(null);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setDoubleTapThreshold(int milliseconds) async {}

  void dispose() => _controller.close();
}

class MockRecordingService implements RecordingService {
  final _controller = StreamController<RecordingState>.broadcast();
  bool started = false;
  bool stopped = false;
  bool cancelled = false;

  @override
  Stream<RecordingState> get stateStream => _controller.stream;

  @override
  Future<void> startRecording() async {
    started = true;
  }

  @override
  Future<void> stopRecording() async {
    stopped = true;
  }

  @override
  Future<void> cancelRecording() async {
    cancelled = true;
  }

  void emitState(RecordingState state) => _controller.add(state);
  void dispose() => _controller.close();
}

class MockProcessingService implements ProcessingService {
  final _controller = StreamController<ProcessingState>.broadcast();
  bool processCalled = false;
  bool cancelCalled = false;
  int? lastSlot;

  @override
  Stream<ProcessingState> get stateStream => _controller.stream;

  @override
  Future<void> processWithProfile(String transcript, int slot) async {
    processCalled = true;
    lastSlot = slot;
  }

  @override
  void cancel() {
    cancelCalled = true;
  }

  @override
  void reset() {}

  void emitState(ProcessingState state) => _controller.add(state);
  void dispose() => _controller.close();
}

class MockPasteService implements PasteService {
  String? lastPasted;

  @override
  Future<bool> pasteText(String text) async {
    lastPasted = text;
    return true;
  }
}

class MockHistoryService implements HistoryService {
  bool saved = false;
  String? lastRawTranscript;
  String? lastProfileName;

  @override
  Future<void> saveEntry({
    required String rawTranscript,
    String? profileName,
    String? processedText,
    required String pastedText,
    double? durationSeconds,
  }) async {
    saved = true;
    lastRawTranscript = rawTranscript;
    lastProfileName = profileName;
  }

  @override
  Future<List<dynamic>> getAllEntries() async => [];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> clearAll() async {}
}

class MockSettingsService implements SettingsService {
  bool soundCues = true;
  bool historyEnabled = true;

  @override
  Future<bool> getSoundCuesEnabled() async => soundCues;
  @override
  Future<bool> getHistoryEnabled() async => historyEnabled;

  // Stubs for the rest of the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockOverlayWindow implements OverlayWindow {
  bool shown = false;
  bool hidden = false;

  @override
  bool get isVisible => shown && !hidden;

  @override
  Future<void> show() async {
    shown = true;
    hidden = false;
  }

  @override
  Future<void> hide() async {
    hidden = true;
    shown = false;
  }

  @override
  Future<void> updateSize(double height) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockHotkeyService hotkey;
  late MockRecordingService recording;
  late MockProcessingService processing;
  late MockPasteService paste;
  late MockHistoryService history;
  late MockSettingsService settings;
  late MockOverlayWindow overlay;
  late OverlayController controller;

  setUp(() {
    hotkey = MockHotkeyService();
    recording = MockRecordingService();
    processing = MockProcessingService();
    paste = MockPasteService();
    history = MockHistoryService();
    settings = MockSettingsService();
    overlay = MockOverlayWindow();

    controller = OverlayController(
      recordingService: recording,
      processingService: processing,
      pasteService: paste,
      historyService: history,
      hotkeyService: hotkey,
      overlayWindow: overlay,
      settingsService: settings,
    );

    controller.initialize();
  });

  tearDown(() {
    controller.dispose();
    hotkey.dispose();
    recording.dispose();
    processing.dispose();
  });

  test('initial state is hidden', () {
    expect(controller.state.phase, OverlayPhase.hidden);
  });

  test('double-tap starts recording', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.phase, OverlayPhase.recording);
    expect(recording.started, isTrue);
    expect(overlay.isVisible, isTrue);
  });

  test('second double-tap stops recording and goes to transcriptComplete',
      () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.phase, OverlayPhase.recording);

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(recording.stopped, isTrue);
    expect(controller.state.phase, OverlayPhase.transcriptComplete);
  });

  test('transcript updates during recording', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'hello world',
    ));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.transcript, 'hello world');
  });

  test('Enter on transcriptComplete pastes raw and hides', () async {
    // Get to transcriptComplete
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'test transcript',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.enter);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(paste.lastPasted, 'test transcript');
    expect(controller.state.phase, OverlayPhase.hidden);
  });

  test('pressing 1-4 starts processing with profile', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'hello',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    // Profiles are loaded from defaults (slot 1 = "Structured prompt")
    expect(controller.state.profiles, isNotEmpty);

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.state.phase, OverlayPhase.processing);
    expect(processing.processCalled, isTrue);
    expect(processing.lastSlot, 1);
  });

  test('processing completion goes to readyToPaste', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'hello',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    processing.emitState(ProcessingState(
      status: ProcessingStatus.complete,
      streamingOutput: 'processed output',
      finalOutput: 'processed output',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.state.phase, OverlayPhase.readyToPaste);
    expect(controller.state.processedText, 'processed output');
  });

  test('Enter on readyToPaste pastes processed text', () async {
    // Drive to readyToPaste state
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'raw text',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    processing.emitState(ProcessingState(
      status: ProcessingStatus.complete,
      streamingOutput: 'processed',
      finalOutput: 'processed',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.enter);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(paste.lastPasted, 'processed');
    expect(controller.state.phase, OverlayPhase.hidden);
  });

  test('Esc cancels from recording', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.phase, OverlayPhase.recording);

    await controller.handleKey(LogicalKeyboardKey.escape);
    expect(controller.state.phase, OverlayPhase.hidden);
    expect(recording.cancelled, isTrue);
  });

  test('Esc cancels from transcriptComplete', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.phase, OverlayPhase.transcriptComplete);

    await controller.handleKey(LogicalKeyboardKey.escape);
    expect(controller.state.phase, OverlayPhase.hidden);
  });

  test('Esc cancels from processing', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'test',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.escape);
    expect(controller.state.phase, OverlayPhase.hidden);
    expect(processing.cancelCalled, isTrue);
  });

  test('processing error goes to error state', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'test',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    processing.emitState(ProcessingState(
      status: ProcessingStatus.error,
      errorMessage: 'API error',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.state.phase, OverlayPhase.error);
    expect(controller.state.errorMessage, 'API error');
  });

  test('Enter on error with transcript pastes raw', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'fallback text',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.digit1);
    await Future.delayed(const Duration(milliseconds: 50));

    processing.emitState(ProcessingState(
      status: ProcessingStatus.error,
      errorMessage: 'fail',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.enter);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(paste.lastPasted, 'fallback text');
    expect(controller.state.phase, OverlayPhase.hidden);
  });

  test('pressing empty profile slot does nothing', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'test',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    // Slot 4 is empty by default
    await controller.handleKey(LogicalKeyboardKey.digit4);
    await Future.delayed(const Duration(milliseconds: 50));

    // Should still be on transcriptComplete, not processing
    expect(controller.state.phase, OverlayPhase.transcriptComplete);
    expect(processing.processCalled, isFalse);
  });

  test('history is saved on paste when enabled', () async {
    settings.historyEnabled = true;

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.recording,
      currentTranscript: 'save me',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    await controller.handleKey(LogicalKeyboardKey.enter);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(history.saved, isTrue);
    expect(history.lastRawTranscript, 'save me');
  });

  test('recording error transitions to error state', () async {
    hotkey.emitDoubleTap();
    await Future.delayed(const Duration(milliseconds: 50));

    recording.emitState(RecordingState(
      status: RecordingStatus.error,
      errorMessage: 'No mic permission',
    ));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.state.phase, OverlayPhase.error);
    expect(controller.state.errorMessage, 'No mic permission');
  });
}

// ---------------------------------------------------------------------------
// Stub types matching Agent 2 & 3 interfaces
// ---------------------------------------------------------------------------

enum RecordingStatus { idle, recording, complete, error }

class RecordingState {
  final RecordingStatus status;
  final String currentTranscript;
  final String? errorMessage;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.currentTranscript = '',
    this.errorMessage,
  });
}

enum ProcessingStatus { idle, processing, complete, error }

class ProcessingState {
  final ProcessingStatus status;
  final String streamingOutput;
  final String finalOutput;
  final String? errorMessage;

  ProcessingState({
    this.status = ProcessingStatus.idle,
    this.streamingOutput = '',
    this.finalOutput = '',
    this.errorMessage,
  });
}
