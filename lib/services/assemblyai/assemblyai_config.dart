/// Configuration constants for the AssemblyAI Real-Time Streaming API.
class AssemblyAIConfig {
  AssemblyAIConfig._();

  /// WebSocket endpoint for real-time transcription.
  static const String wsUrl = 'wss://api.assemblyai.com/v2/realtime/ws';

  /// Audio sample rate in Hz. Must match what AudioService produces.
  static const int sampleRate = 16000;

  /// How often audio chunks are sent over the WebSocket.
  static const Duration sendInterval = Duration(milliseconds: 100);

  /// Builds the full WebSocket URL with query parameters.
  static String buildWsUrl(String apiKey) {
    return '$wsUrl?sample_rate=$sampleRate&token=$apiKey';
  }
}
