/// Data models for AssemblyAI Real-Time Streaming API v3 messages.

/// Information about a single transcribed word.
class WordInfo {
  final String text;
  final int start;
  final int end;
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
}

/// Known v3 message types returned by the AssemblyAI real-time API.
class AssemblyAIMessageTypes {
  AssemblyAIMessageTypes._();

  static const String begin = 'Begin';
  static const String turn = 'Turn';
  static const String speechStarted = 'SpeechStarted';
  static const String termination = 'Termination';
  static const String error = 'Error';
}

/// A deserialized message received from the AssemblyAI v3 WebSocket.
class AssemblyAIMessage {
  final String type;
  final String? transcript;
  final bool? endOfTurn;
  final bool? turnIsFormatted;
  final int? turnOrder;
  final double? endOfTurnConfidence;
  final String? utterance;
  final List<WordInfo>? words;
  final String? error;

  const AssemblyAIMessage({
    required this.type,
    this.transcript,
    this.endOfTurn,
    this.turnIsFormatted,
    this.turnOrder,
    this.endOfTurnConfidence,
    this.utterance,
    this.words,
    this.error,
  });

  factory AssemblyAIMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';

    List<WordInfo>? words;
    if (json['words'] != null) {
      words = (json['words'] as List<dynamic>)
          .map((w) => WordInfo.fromJson(w as Map<String, dynamic>))
          .toList();
    }

    return AssemblyAIMessage(
      type: type,
      transcript: json['transcript'] as String?,
      endOfTurn: json['end_of_turn'] as bool?,
      turnIsFormatted: json['turn_is_formatted'] as bool?,
      turnOrder: json['turn_order'] as int?,
      endOfTurnConfidence:
          (json['end_of_turn_confidence'] as num?)?.toDouble(),
      utterance: json['utterance'] as String?,
      words: words,
      error: json['error'] as String?,
    );
  }

  /// Whether this is a Turn message (partial or final transcript).
  bool get isTurn => type == AssemblyAIMessageTypes.turn;

  /// Whether this turn is final (end_of_turn == true).
  bool get isFinalTurn => isTurn && (endOfTurn == true);

  /// Whether this turn is partial (end_of_turn == false).
  bool get isPartialTurn => isTurn && (endOfTurn != true);

  /// Whether the session has begun.
  bool get isBegin => type == AssemblyAIMessageTypes.begin;

  /// Whether the session has been terminated.
  bool get isTermination => type == AssemblyAIMessageTypes.termination;

  /// Whether this is an error message.
  bool get isError => type == AssemblyAIMessageTypes.error;
}
