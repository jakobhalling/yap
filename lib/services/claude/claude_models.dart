/// Request model for the Claude Messages API.
class ClaudeRequest {
  final String model;
  final int maxTokens;
  final bool stream;
  final String system;
  final List<ClaudeMessage> messages;

  const ClaudeRequest({
    required this.model,
    required this.maxTokens,
    this.stream = true,
    required this.system,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        'max_tokens': maxTokens,
        'stream': stream,
        'system': system,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

/// A single message in the Claude conversation.
class ClaudeMessage {
  final String role;
  final String content;

  const ClaudeMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Parsed SSE event from the Claude streaming response.
class ClaudeStreamEvent {
  final String type;
  final String? text;
  final String? errorMessage;

  const ClaudeStreamEvent({
    required this.type,
    this.text,
    this.errorMessage,
  });
}

// --- Exceptions ---

/// Base exception for Claude API errors. Never exposes the API key.
class ClaudeApiException implements Exception {
  final String message;
  final int? statusCode;

  const ClaudeApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ClaudeApiException: $message';
}

/// Thrown when the API key is invalid or missing.
class ClaudeAuthException extends ClaudeApiException {
  const ClaudeAuthException([String message = 'Invalid or missing API key'])
      : super(message, statusCode: 401);
}

/// Thrown when rate-limited by the API.
class ClaudeRateLimitException extends ClaudeApiException {
  final Duration? retryAfter;

  const ClaudeRateLimitException({
    String message = 'Rate limited by Claude API',
    this.retryAfter,
  }) : super(message, statusCode: 429);
}
