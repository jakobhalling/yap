/// Configuration constants for the AssemblyAI Real-Time Streaming API (v3).
class AssemblyAIConfig {
  AssemblyAIConfig._();

  /// REST endpoint to create a temporary authentication token.
  static const String tokenUrl =
      'https://streaming.assemblyai.com/v3/token';

  /// WebSocket endpoint for real-time transcription.
  static const String wsUrl = 'wss://streaming.assemblyai.com/v3/ws';

  /// Audio sample rate in Hz. Must match what AudioService produces.
  static const int sampleRate = 16000;

  /// Audio encoding format.
  static const String encoding = 'pcm_s16le';

  /// Speech model to use.
  static const String speechModel = 'universal-streaming-english';

  /// How often audio chunks are sent over the WebSocket.
  static const Duration sendInterval = Duration(milliseconds: 100);

  /// Builds the full WebSocket URL with a temporary token.
  static String buildWsUrl(String tempToken) {
    return '$wsUrl'
        '?token=$tempToken'
        '&speech_model=$speechModel'
        '&sample_rate=$sampleRate'
        '&encoding=$encoding';
  }
}
