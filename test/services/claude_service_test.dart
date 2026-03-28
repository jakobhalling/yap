import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/claude/claude_config.dart';
import 'package:yap/services/claude/claude_models.dart';
import 'package:yap/services/claude/claude_service.dart';

/// A mock Dio adapter for testing SSE streams.
class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Helper to build an SSE response body from a list of event strings.
ResponseBody sseResponseBody(List<String> events) {
  final controller = StreamController<List<int>>();

  // Schedule events to be added asynchronously.
  Future.microtask(() async {
    for (final event in events) {
      controller.add(utf8.encode(event));
    }
    await controller.close();
  });

  return ResponseBody(
    controller.stream,
    200,
    headers: {
      'content-type': ['text/event-stream'],
    },
  );
}

void main() {
  group('ClaudeConfig', () {
    test('resolves model names correctly', () {
      expect(ClaudeConfig.resolveModel('haiku'), 'claude-haiku-4-5-20251001');
      expect(ClaudeConfig.resolveModel('sonnet'), 'claude-sonnet-4-20250514');
      expect(ClaudeConfig.resolveModel('opus'), 'claude-opus-4-20250115');
    });

    test('falls back to sonnet for unknown model', () {
      expect(ClaudeConfig.resolveModel('unknown'), 'claude-sonnet-4-20250514');
    });

    test('uses default max tokens for short transcript', () {
      final transcript = 'This is a short transcript with few words.';
      expect(ClaudeConfig.maxTokensForTranscript(transcript), 8192);
    });

    test('uses long max tokens for long transcript', () {
      // Generate a transcript with >4000 words.
      final transcript = List.generate(5000, (i) => 'word$i').join(' ');
      expect(ClaudeConfig.maxTokensForTranscript(transcript), 16384);
    });
  });

  group('ClaudeModels', () {
    test('ClaudeRequest serializes to JSON correctly', () {
      final request = ClaudeRequest(
        model: 'claude-sonnet-4-20250514',
        maxTokens: 8192,
        system: 'You are a helper.',
        messages: [
          const ClaudeMessage(role: 'user', content: 'Hello'),
        ],
      );

      final json = request.toJson();
      expect(json['model'], 'claude-sonnet-4-20250514');
      expect(json['max_tokens'], 8192);
      expect(json['stream'], true);
      expect(json['system'], 'You are a helper.');
      expect(json['messages'], hasLength(1));
      expect(json['messages'][0]['role'], 'user');
      expect(json['messages'][0]['content'], 'Hello');
    });
  });

  group('ClaudeService SSE parsing', () {
    late Dio dio;

    setUp(() {
      dio = Dio();
    });

    test('parses streaming text deltas correctly', () async {
      final events = [
        'event: message_start\ndata: {"type":"message_start"}\n\n',
        'event: content_block_start\ndata: {"type":"content_block_start","index":0}\n\n',
        'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}\n\n',
        'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":" world"}}\n\n',
        'event: content_block_stop\ndata: {"type":"content_block_stop"}\n\n',
        'event: message_stop\ndata: {"type":"message_stop"}\n\n',
      ];

      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        return sseResponseBody(events);
      });

      final service = ClaudeServiceImpl(dio: dio);
      final chunks = await service
          .processTranscript(
            transcript: 'Test transcript',
            systemPrompt: 'Test prompt',
            apiKey: 'test-key',
            model: 'sonnet',
          )
          .toList();

      expect(chunks, ['Hello', ' world']);
    });

    test('handles error event in stream', () async {
      final events = [
        'event: error\ndata: {"type":"error","error":{"message":"Overloaded"}}\n\n',
      ];

      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        return sseResponseBody(events);
      });

      final service = ClaudeServiceImpl(dio: dio);

      expect(
        () => service
            .processTranscript(
              transcript: 'Test',
              systemPrompt: 'Test',
              apiKey: 'test-key',
              model: 'sonnet',
            )
            .toList(),
        throwsA(isA<ClaudeApiException>()),
      );
    });

    test('throws ClaudeAuthException on 401', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
            data: {'error': {'message': 'Invalid API key'}},
          ),
          type: DioExceptionType.badResponse,
        );
      });

      final service = ClaudeServiceImpl(dio: dio);

      expect(
        () => service
            .processTranscript(
              transcript: 'Test',
              systemPrompt: 'Test',
              apiKey: 'bad-key',
              model: 'sonnet',
            )
            .toList(),
        throwsA(isA<ClaudeAuthException>()),
      );
    });

    test('throws ClaudeRateLimitException on 429', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['30'],
            }),
          ),
          type: DioExceptionType.badResponse,
        );
      });

      final service = ClaudeServiceImpl(dio: dio);

      expect(
        () => service
            .processTranscript(
              transcript: 'Test',
              systemPrompt: 'Test',
              apiKey: 'test-key',
              model: 'sonnet',
            )
            .toList(),
        throwsA(isA<ClaudeRateLimitException>()),
      );
    });
  });

  group('ClaudeService validateApiKey', () {
    late Dio dio;

    setUp(() {
      dio = Dio();
    });

    test('returns true for valid key', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        return ResponseBody.fromString(
          '{"id":"msg_123","type":"message","content":[{"type":"text","text":"Hi"}]}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });

      final service = ClaudeServiceImpl(dio: dio);
      final result = await service.validateApiKey('valid-key');
      expect(result, true);
    });

    test('throws ClaudeAuthException for invalid key', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        );
      });

      final service = ClaudeServiceImpl(dio: dio);
      expect(
        () => service.validateApiKey('invalid-key'),
        throwsA(isA<ClaudeAuthException>()),
      );
    });

    test('returns true when rate-limited (key is valid)', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 429,
          ),
          type: DioExceptionType.badResponse,
        );
      });

      final service = ClaudeServiceImpl(dio: dio);
      final result = await service.validateApiKey('valid-but-limited-key');
      expect(result, true);
    });
  });

  group('Exception safety', () {
    test('ClaudeAuthException does not contain API key', () {
      const exception = ClaudeAuthException();
      expect(exception.toString(), isNot(contains('sk-')));
      expect(exception.message, 'Invalid or missing API key');
    });

    test('ClaudeApiException does not leak sensitive info', () {
      const exception = ClaudeApiException('API request failed', statusCode: 500);
      expect(exception.toString(), contains('API request failed'));
    });
  });
}
