import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/services/assemblyai/assemblyai_service.dart';
import 'package:yap/services/providers.dart';
import 'package:yap/features/settings/settings_providers.dart';

import 'recording_service.dart';
import 'recording_state.dart';

/// Provider for the AssemblyAI real-time service.
final assemblyAIServiceProvider = Provider<AssemblyAIService>((ref) {
  return AssemblyAIServiceImpl();
});

/// Provider for the [RecordingService] that coordinates audio capture
/// and real-time transcription.
final recordingServiceProvider = Provider<RecordingService>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final assemblyAI = ref.watch(assemblyAIServiceProvider);
  // Read the API key synchronously from the future provider's cached value.
  final apiKeyAsync = ref.watch(assemblyAIApiKeyProvider);
  final apiKey = apiKeyAsync.valueOrNull;

  final service = RecordingServiceImpl(
    audioService: audioService,
    assemblyAIService: assemblyAI,
    apiKey: apiKey,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

/// Stream provider for reactive recording state updates.
final recordingStateProvider = StreamProvider<RecordingState>((ref) {
  return ref.watch(recordingServiceProvider).stateStream;
});
