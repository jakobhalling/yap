/// Data models for AssemblyAI Real-Time Streaming API messages.

/// Information about a single transcribed word.
class WordInfo {
  final String text;

  /// Start time in milliseconds from the beginning of the audio stream.
  final int start;

  /// End time in milliseconds from the beginning of the audio stream.
  final int end;

  /// Confidence score from 0.0 to 1.0.
  final double confidence;

  const WordInfo({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
  });

  factory WordInfo.fromJson(Map<String, dynamic> json) {
    return WordInfo(
      text: json['text'] as String? ?? '',
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'start': start,
        'end': end,
        'confidence': confidence,
      };
}

/// Known message types returned by the AssemblyAI real-time API.
class AssemblyAIMessageTypes {
  AssemblyAIMessageTypes._();

  static const String partialTranscript = 'PartialTranscript';
  static const String finalTranscript = 'FinalTranscript';
  static const String sessionBegins = 'SessionBegins';
  static const String sessionTerminated = 'SessionTerminated';
  static const String sessionInformation = 'SessionInformation';
  static const String error = 'error';
}

/// A deserialized message received from the AssemblyAI WebSocket.
class AssemblyAIMessage {
  final String messageType;
  final String? text;

  /// Audio start time in milliseconds.
  final int? audioStart;

  /// Audio end time in milliseconds.
  final int? audioEnd;

  final List<WordInfo>? words;

  /// Session ID, present in SessionBegins messages.
  final String? sessionId;

  /// Error message, present when an error occurs.
  final String? error;

  const AssemblyAIMessage({
    required this.messageType,
    this.text,
    this.audioStart,
    this.audioEnd,
    this.words,
    this.sessionId,
    this.error,
  });

  factory AssemblyAIMessage.fromJson(Map<String, dynamic> json) {
    final messageType = json['message_type'] as String? ?? '';

    List<WordInfo>? words;
    if (json['words'] != null) {
      words = (json['words'] as List<dynamic>)
          .map((w) => WordInfo.fromJson(w as Map<String, dynamic>))
          .toList();
    }

    return AssemblyAIMessage(
      messageType: messageType,
      text: json['text'] as String?,
      audioStart: json['audio_start'] as int?,
      audioEnd: json['audio_end'] as int?,
      words: words,
      sessionId: json['session_id'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Whether this is a partial transcript (interim, will be replaced).
  bool get isPartial =>
      messageType == AssemblyAIMessageTypes.partialTranscript;

  /// Whether this is a final transcript (committed, won't change).
  bool get isFinal => messageType == AssemblyAIMessageTypes.finalTranscript;

  /// Whether the session has been terminated by the server.
  bool get isSessionTerminated =>
      messageType == AssemblyAIMessageTypes.sessionTerminated;

  /// Whether the session has just begun.
  bool get isSessionBegins =>
      messageType == AssemblyAIMessageTypes.sessionBegins;
}
