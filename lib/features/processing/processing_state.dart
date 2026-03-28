/// Status of LLM transcript processing.
enum ProcessingStatus {
  idle,
  processing,
  complete,
  error,
}

/// Immutable state model for the processing pipeline.
class ProcessingState {
  final ProcessingStatus status;
  final String? profileName;
  final String streamingOutput; // Grows as chunks arrive
  final String? finalOutput; // Complete output when done
  final String? errorMessage;

  const ProcessingState({
    this.status = ProcessingStatus.idle,
    this.profileName,
    this.streamingOutput = '',
    this.finalOutput,
    this.errorMessage,
  });

  ProcessingState copyWith({
    ProcessingStatus? status,
    String? profileName,
    String? streamingOutput,
    String? finalOutput,
    String? errorMessage,
  }) {
    return ProcessingState(
      status: status ?? this.status,
      profileName: profileName ?? this.profileName,
      streamingOutput: streamingOutput ?? this.streamingOutput,
      finalOutput: finalOutput ?? this.finalOutput,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convenience factory for the initial idle state.
  static const ProcessingState idle = ProcessingState();
}
