import 'dart:async';

import 'package:flutter/services.dart';

import 'package:yap/features/overlay/overlay_window.dart';
import 'package:yap/features/processing/processing_service.dart';
import 'package:yap/features/processing/processing_state.dart';
import 'package:yap/features/recording/recording_service.dart';
import 'package:yap/features/recording/recording_state.dart';
import 'package:yap/features/history/history_service.dart';
import 'package:yap/features/settings/settings_service.dart';
import 'package:yap/services/hotkey/hotkey_service.dart';
import 'package:yap/services/paste/paste_service.dart';
import 'package:yap/services/database/daos/prompt_profile_dao.dart';
import 'package:yap/shared/prompts/default_prompts.dart';

// ---------------------------------------------------------------------------
// State types
// ---------------------------------------------------------------------------

enum OverlayPhase {
  hidden,
  recording,
  transcriptComplete,
  processing,
  readyToPaste,
  error,
}

class ProfileOption {
  final int slot;
  final String name;
  final bool isEmpty;

  const ProfileOption({
    required this.slot,
    required this.name,
    required this.isEmpty,
  });
}

class YapOverlayState {
  final OverlayPhase phase;
  final String transcript;
  final String processedText;
  final String? profileName;
  final Duration elapsed;
  final String? errorMessage;
  final List<ProfileOption> profiles;

  const YapOverlayState({
    this.phase = OverlayPhase.hidden,
    this.transcript = '',
    this.processedText = '',
    this.profileName,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.profiles = const [],
  });

  YapOverlayState copyWith({
    OverlayPhase? phase,
    String? transcript,
    String? processedText,
    String? profileName,
    Duration? elapsed,
    String? errorMessage,
    List<ProfileOption>? profiles,
  }) {
    return YapOverlayState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      processedText: processedText ?? this.processedText,
      profileName: profileName ?? this.profileName,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: errorMessage ?? this.errorMessage,
      profiles: profiles ?? this.profiles,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class OverlayController {
  final RecordingService recordingService;
  final ProcessingService processingService;
  final PasteService pasteService;
  final HistoryService historyService;
  final HotkeyService hotkeyService;
  final OverlayWindow overlayWindow;
  final SettingsService settingsService;
  final PromptProfileDao? profileDao;

  OverlayController({
    required this.recordingService,
    required this.processingService,
    required this.pasteService,
    required this.historyService,
    required this.hotkeyService,
    required this.overlayWindow,
    required this.settingsService,
    this.profileDao,
  });

  YapOverlayState _state = const YapOverlayState();
  final _stateController = StreamController<YapOverlayState>.broadcast();

  YapOverlayState get state => _state;
  Stream<YapOverlayState> get stateStream => _stateController.stream;

  StreamSubscription<void>? _hotkeySub;
  StreamSubscription<RecordingState>? _recordingSub;
  StreamSubscription<ProcessingState>? _processingSub;
  Timer? _elapsedTimer;

  // ---- lifecycle -----------------------------------------------------------

  void initialize() {
    _hotkeySub = hotkeyService.onDoubleTap.listen((_) => _handleDoubleTap());
  }

  void dispose() {
    _hotkeySub?.cancel();
    _recordingSub?.cancel();
    _processingSub?.cancel();
    _elapsedTimer?.cancel();
    _stateController.close();
  }

  // ---- private helpers -----------------------------------------------------

  void _emit(YapOverlayState s) {
    _state = s;
    _stateController.add(s);
  }

  Future<List<ProfileOption>> _loadProfiles() async {
    if (profileDao != null) {
      try {
        final profiles = await profileDao!.getAllProfiles();
        return profiles
            .map((p) => ProfileOption(
                  slot: p.slot,
                  name: p.name,
                  isEmpty: p.name.isEmpty && p.systemPrompt.isEmpty,
                ))
            .toList();
      } catch (_) {
        // fall through to defaults
      }
    }
    return DefaultPrompts.defaults
        .map((d) => ProfileOption(
              slot: d.slot,
              name: d.name,
              isEmpty: d.name.isEmpty && d.systemPrompt.isEmpty,
            ))
        .toList();
  }

  void _startElapsedTimer() {
    final start = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(start);
      _emit(_state.copyWith(elapsed: elapsed));
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  /// Public method for tray menu toggle. Same behavior as double-tap.
  Future<void> handleTrayToggle() => _handleDoubleTap();

  // ---- double-tap ----------------------------------------------------------

  Future<void> _handleDoubleTap() async {
    if (_state.phase == OverlayPhase.hidden) {
      await _startRecording();
    } else if (_state.phase == OverlayPhase.recording) {
      await _stopRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      _emit(_state.copyWith(
        phase: OverlayPhase.recording,
        transcript: '',
        processedText: '',
        profileName: null,
        errorMessage: null,
        elapsed: Duration.zero,
      ));
      await overlayWindow.show();
      await recordingService.startRecording();
      _startElapsedTimer();

      _recordingSub?.cancel();
      _recordingSub = recordingService.stateStream.listen((rs) {
        if (_state.phase != OverlayPhase.recording) return;
        _emit(_state.copyWith(transcript: rs.currentTranscript));
        if (rs.status == RecordingStatus.error) {
          _stopElapsedTimer();
          _emit(_state.copyWith(
            phase: OverlayPhase.error,
            errorMessage: rs.errorMessage ?? 'Recording error',
          ));
        }
      });
    } catch (e) {
      _emit(_state.copyWith(
        phase: OverlayPhase.error,
        errorMessage: e.toString(),
      ));
      await overlayWindow.show();
    }
  }

  Future<void> _stopRecording() async {
    try {
      _stopElapsedTimer();
      await recordingService.stopRecording();
      _recordingSub?.cancel();

      final profiles = await _loadProfiles();
      _emit(_state.copyWith(
        phase: OverlayPhase.transcriptComplete,
        profiles: profiles,
      ));
    } catch (e) {
      _emit(_state.copyWith(
        phase: OverlayPhase.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ---- keyboard handling ---------------------------------------------------

  Future<void> handleKey(LogicalKeyboardKey key) async {
    if (key == LogicalKeyboardKey.escape) {
      cancel();
      return;
    }

    switch (_state.phase) {
      case OverlayPhase.transcriptComplete:
        if (key == LogicalKeyboardKey.enter) {
          await _pasteRawAndClose();
        } else if (key == LogicalKeyboardKey.digit1) {
          await processWithProfile(1);
        } else if (key == LogicalKeyboardKey.digit2) {
          await processWithProfile(2);
        } else if (key == LogicalKeyboardKey.digit3) {
          await processWithProfile(3);
        } else if (key == LogicalKeyboardKey.digit4) {
          await processWithProfile(4);
        }
        break;
      case OverlayPhase.readyToPaste:
        if (key == LogicalKeyboardKey.enter) {
          await pasteAndClose();
        }
        break;
      case OverlayPhase.error:
        if (key == LogicalKeyboardKey.enter && _state.transcript.isNotEmpty) {
          await _pasteRawAndClose();
        }
        break;
      default:
        break;
    }
  }

  // ---- processing ----------------------------------------------------------

  Future<void> processWithProfile(int slot) async {
    final profile = _state.profiles.where((p) => p.slot == slot).firstOrNull;
    if (profile == null || profile.isEmpty) return;

    try {
      _emit(_state.copyWith(
        phase: OverlayPhase.processing,
        profileName: profile.name,
        processedText: '',
      ));

      await processingService.processWithProfile(
        transcript: _state.transcript,
        profileSlot: slot,
      );

      _processingSub?.cancel();
      _processingSub = processingService.stateStream.listen((ps) {
        if (_state.phase != OverlayPhase.processing) return;
        _emit(_state.copyWith(processedText: ps.streamingOutput));
        if (ps.status == ProcessingStatus.complete) {
          _emit(_state.copyWith(
            phase: OverlayPhase.readyToPaste,
            processedText: ps.finalOutput,
          ));
          _processingSub?.cancel();
        } else if (ps.status == ProcessingStatus.error) {
          _emit(_state.copyWith(
            phase: OverlayPhase.error,
            errorMessage: ps.errorMessage ?? 'Processing error',
          ));
          _processingSub?.cancel();
        }
      });
    } catch (e) {
      _emit(_state.copyWith(
        phase: OverlayPhase.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ---- paste ---------------------------------------------------------------

  Future<void> pasteAndClose() async {
    final text = _state.processedText.isNotEmpty
        ? _state.processedText
        : _state.transcript;
    await _pasteAndSave(text, isProcessed: _state.processedText.isNotEmpty);
  }

  Future<void> _pasteRawAndClose() async {
    await _pasteAndSave(_state.transcript, isProcessed: false);
  }

  Future<void> _pasteAndSave(String text, {required bool isProcessed}) async {
    try {
      await pasteService.pasteText(text);
    } catch (_) {
      // If paste fails, text is already on clipboard — acceptable fallback.
    }

    // Save to history.
    try {
      final historyEnabled = await settingsService.getHistoryEnabled();
      if (historyEnabled) {
        await historyService.saveEntry(
          rawTranscript: _state.transcript,
          profileName: isProcessed ? _state.profileName : null,
          processedText: isProcessed ? _state.processedText : null,
          pastedText: text,
          durationSeconds: _state.elapsed.inSeconds.toDouble(),
        );
      }
    } catch (_) {
      // History save failure is non-critical.
    }

    _reset();
    await overlayWindow.hide();
  }

  // ---- cancel / reset ------------------------------------------------------

  void cancel() {
    if (_state.phase == OverlayPhase.recording) {
      recordingService.cancelRecording();
      _stopElapsedTimer();
      _recordingSub?.cancel();
    }
    if (_state.phase == OverlayPhase.processing) {
      processingService.cancel();
      _processingSub?.cancel();
    }
    _reset();
    overlayWindow.hide();
  }

  void _reset() {
    _emit(const YapOverlayState());
  }
}
