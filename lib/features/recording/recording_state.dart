/// State model for a recording session.

/// The current phase of the recording lifecycle.
enum RecordingStatus {
  /// Not recording — the default/resting state.
  idle,

  /// Actively capturing audio and receiving transcription.
  recording,

  /// User requested stop; waiting for the final transcript from AssemblyAI.
  stopping,

  /// Transcript is ready for the user to review / send to LLM.
  complete,

  /// An error occurred during recording or transcription.
  error,
}

/// Immutable snapshot of the recording session state.
class RecordingState {
  final RecordingStatus status;

  /// Latest display text: all finals joined + the current partial.
  final String currentTranscript;

  /// Only committed final segments (used for LLM processing).
  final String finalTranscript;

  /// How long the user has been recording.
  final Duration elapsed;

  /// Human-readable error description when [status] is [RecordingStatus.error].
  final String? errorMessage;

  /// When the recording started (null when idle).
  final DateTime? startedAt;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.currentTranscript = '',
    this.finalTranscript = '',
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.startedAt,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    String? currentTranscript,
    String? finalTranscript,
    Duration? elapsed,
    String? errorMessage,
    DateTime? startedAt,
  }) {
    return RecordingState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  String toString() =>
      'RecordingState(status=$status, elapsed=$elapsed, '
      'transcript="${currentTranscript.length > 40 ? '${currentTranscript.substring(0, 40)}...' : currentTranscript}")';
}
