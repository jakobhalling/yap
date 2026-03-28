import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'claude_config.dart';
import 'claude_models.dart';

/// Abstract interface for the Claude API client.
abstract class ClaudeService {
  /// Process a transcript with a given system prompt.
  /// Returns a stream of text chunks (for streaming display in the UI).
  Stream<String> processTranscript({
    required String transcript,
    required String systemPrompt,
    required String apiKey,
    required String model,
  });

  /// Validate that an API key works.
  /// Returns true if the key is valid, throws with details if not.
  Future<bool> validateApiKey(String apiKey);
}

/// Production implementation using Dio for HTTP + SSE streaming.
class ClaudeServiceImpl implements ClaudeService {
  final Dio _dio;

  ClaudeServiceImpl({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Stream<String> processTranscript({
    required String transcript,
    required String systemPrompt,
    required String apiKey,
    required String model,
  }) async* {
    final resolvedModel = ClaudeConfig.resolveModel(model);
    final maxTokens = ClaudeConfig.maxTokensForTranscript(transcript);

    final request = ClaudeRequest(
      model: resolvedModel,
      maxTokens: maxTokens,
      stream: true,
      system: systemPrompt,
      messages: [
        ClaudeMessage(role: 'user', content: transcript),
      ],
    );

    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        ClaudeConfig.apiUrl,
        data: request.toJson(),
        options: Options(
          headers: _buildHeaders(apiKey),
          responseType: ResponseType.stream,
        ),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const ClaudeApiException('No response stream received');
    }

    yield* _parseSSEStream(stream);
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    // Send a minimal request to validate the key.
    try {
      await _dio.post(
        ClaudeConfig.apiUrl,
        data: {
          'model': ClaudeConfig.resolveModel('haiku'),
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        },
        options: Options(
          headers: _buildHeaders(apiKey),
        ),
      );
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw const ClaudeAuthException();
      }
      if (statusCode == 429) {
        // Key is valid but rate-limited — that's fine, key works.
        return true;
      }
      throw _mapDioError(e);
    }
  }

  Map<String, String> _buildHeaders(String apiKey) => {
        'x-api-key': apiKey,
        'anthropic-version': ClaudeConfig.apiVersion,
        'content-type': 'application/json',
      };

  /// Parse the SSE byte stream into text delta chunks.
  Stream<String> _parseSSEStream(Stream<List<int>> byteStream) async* {
    String buffer = '';

    await for (final chunk in byteStream) {
      buffer += utf8.decode(chunk);

      // SSE events are separated by double newlines.
      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final eventBlock = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        final event = _parseSSEEvent(eventBlock);
        if (event == null) continue;

        if (event.type == 'content_block_delta' && event.text != null) {
          yield event.text!;
        } else if (event.type == 'message_stop') {
          return;
        } else if (event.type == 'error') {
          throw ClaudeApiException(
              event.errorMessage ?? 'Unknown streaming error');
        }
      }
    }
  }

  /// Parse a single SSE event block (may have multiple lines).
  ClaudeStreamEvent? _parseSSEEvent(String eventBlock) {
    String? eventType;
    String? data;

    for (final line in eventBlock.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        data = line.substring(6);
      }
    }

    if (eventType == null && data == null) return null;

    // Handle the data payload.
    if (data != null && data != '[DONE]') {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final type = json['type'] as String? ?? eventType ?? 'unknown';

        if (type == 'content_block_delta') {
          final delta = json['delta'] as Map<String, dynamic>?;
          final text = delta?['text'] as String?;
          return ClaudeStreamEvent(type: type, text: text);
        }

        if (type == 'message_stop') {
          return const ClaudeStreamEvent(type: 'message_stop');
        }

        if (type == 'error') {
          final error = json['error'] as Map<String, dynamic>?;
          final message = error?['message'] as String? ?? 'Unknown error';
          return ClaudeStreamEvent(type: 'error', errorMessage: message);
        }

        // Return generic event for other types (message_start, etc.)
        return ClaudeStreamEvent(type: type);
      } catch (_) {
        // Malformed JSON — skip this event.
        return null;
      }
    }

    if (eventType != null) {
      return ClaudeStreamEvent(type: eventType);
    }

    return null;
  }

  /// Map Dio errors to typed Claude exceptions. Never leaks the API key.
  ClaudeApiException _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode == 401) {
      return const ClaudeAuthException();
    }

    if (statusCode == 429) {
      final retryAfterHeader = e.response?.headers['retry-after']?.first;
      Duration? retryAfter;
      if (retryAfterHeader != null) {
        final seconds = int.tryParse(retryAfterHeader);
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }
      return ClaudeRateLimitException(retryAfter: retryAfter);
    }

    // Try to extract error message from response body.
    String message = 'API request failed';
    if (statusCode != null) {
      message = 'API request failed with status $statusCode';
    }

    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'] as Map<String, dynamic>?;
        if (error != null) {
          message = error['message'] as String? ?? message;
        }
      }
    } catch (_) {
      // Ignore parse errors on error responses.
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Request timed out';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Could not connect to Claude API';
    }

    return ClaudeApiException(message, statusCode: statusCode);
  }
}
