import 'dart:async';

import '../../services/claude/claude_service.dart';
import '../../services/claude/claude_models.dart';
import '../../services/database/daos/prompt_profile_dao.dart';
import '../settings/settings_service.dart';
import 'processing_state.dart';

/// Thrown when trying to process with an empty/unconfigured profile.
class EmptyProfileException implements Exception {
  final int slot;
  const EmptyProfileException(this.slot);

  @override
  String toString() =>
      'EmptyProfileException: Profile slot $slot has no prompt configured';
}

/// Thrown when the Anthropic API key is not configured.
class NoApiKeyException implements Exception {
  const NoApiKeyException();

  @override
  String toString() =>
      'NoApiKeyException: Anthropic API key is not configured';
}

/// Abstract interface for the processing orchestrator.
abstract class ProcessingService {
  ProcessingState get state;
  Stream<ProcessingState> get stateStream;

  /// Process a transcript with the given profile slot (1-4).
  Future<void> processWithProfile({
    required String transcript,
    required int profileSlot,
  });

  /// Cancel in-progress processing.
  Future<void> cancel();

  /// Reset to idle state.
  void reset();
}

/// Production implementation that ties together Claude API + DB.
class ProcessingServiceImpl implements ProcessingService {
  final ClaudeService _claudeService;
  final PromptProfileDao _profileDao;
  final SettingsService _settingsService;

  ProcessingState _state = ProcessingState.idle;
  final _stateController = StreamController<ProcessingState>.broadcast();
  StreamSubscription<String>? _activeSubscription;

  ProcessingServiceImpl(
    this._claudeService,
    this._profileDao,
    this._settingsService,
  );

  @override
  ProcessingState get state => _state;

  @override
  Stream<ProcessingState> get stateStream => _stateController.stream;

  void _emit(ProcessingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> processWithProfile({
    required String transcript,
    required int profileSlot,
  }) async {
    // 1. Look up the prompt profile.
    final profile = await _profileDao.getProfile(profileSlot);
    if (profile == null || profile.systemPrompt.trim().isEmpty) {
      throw EmptyProfileException(profileSlot);
    }

    // 2. Get the API key.
    final apiKey = await _settingsService.getAnthropicApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const NoApiKeyException();
    }

    // 3. Get the model preference.
    final model = await _settingsService.getClaudeModel();

    // 4. Start processing.
    _emit(ProcessingState(
      status: ProcessingStatus.processing,
      profileName: profile.name,
      streamingOutput: '',
    ));

    final outputBuffer = StringBuffer();

    try {
      final stream = _claudeService.processTranscript(
        transcript: transcript,
        systemPrompt: profile.systemPrompt,
        apiKey: apiKey,
        model: model,
      );

      await for (final chunk in stream) {
        // Check if cancelled.
        if (_state.status != ProcessingStatus.processing) return;

        outputBuffer.write(chunk);
        _emit(_state.copyWith(
          streamingOutput: outputBuffer.toString(),
        ));
      }

      // 5. Processing complete.
      final finalText = outputBuffer.toString();
      _emit(ProcessingState(
        status: ProcessingStatus.complete,
        profileName: profile.name,
        streamingOutput: finalText,
        finalOutput: finalText,
      ));
    } on ClaudeApiException catch (e) {
      _emit(ProcessingState(
        status: ProcessingStatus.error,
        profileName: profile.name,
        streamingOutput: outputBuffer.toString(),
        errorMessage: e.message,
      ));
    } catch (e) {
      _emit(ProcessingState(
        status: ProcessingStatus.error,
        profileName: profile.name,
        streamingOutput: outputBuffer.toString(),
        errorMessage: 'Processing failed: $e',
      ));
    }
  }

  @override
  Future<void> cancel() async {
    await _activeSubscription?.cancel();
    _activeSubscription = null;
    if (_state.status == ProcessingStatus.processing) {
      _emit(_state.copyWith(
        status: ProcessingStatus.error,
        errorMessage: 'Processing cancelled',
      ));
    }
  }

  @override
  void reset() {
    _activeSubscription?.cancel();
    _activeSubscription = null;
    _emit(ProcessingState.idle);
  }

  /// Call this when the service is no longer needed.
  void dispose() {
    _activeSubscription?.cancel();
    _stateController.close();
  }
}
