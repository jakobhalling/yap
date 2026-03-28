/// Configuration constants for the Claude API.
class ClaudeConfig {
  static const String apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String apiVersion = '2023-06-01';

  /// Default max tokens for responses.
  static const int defaultMaxTokens = 8192;

  /// Max tokens for long transcripts (>4000 words).
  static const int longMaxTokens = 16384;

  /// Word count threshold for using long max tokens.
  static const int longTranscriptWordThreshold = 4000;

  /// Map friendly model names to full Claude model IDs.
  static const Map<String, String> modelMapping = {
    'haiku': 'claude-haiku-4-5-20251001',
    'sonnet': 'claude-sonnet-4-20250514',
    'opus': 'claude-opus-4-20250115',
  };

  /// Resolve a friendly name (haiku/sonnet/opus) to a full model ID.
  /// Falls back to sonnet if the name is unrecognized.
  static String resolveModel(String name) {
    return modelMapping[name.toLowerCase()] ?? modelMapping['sonnet']!;
  }

  /// Determine the appropriate max_tokens based on transcript length.
  static int maxTokensForTranscript(String transcript) {
    final wordCount = transcript.split(RegExp(r'\s+')).length;
    if (wordCount > longTranscriptWordThreshold) {
      return longMaxTokens;
    }
    return defaultMaxTokens;
  }
}
