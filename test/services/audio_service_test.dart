import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/audio/audio_service_impl.dart';
import 'package:yap/services/audio/mock_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioServiceImpl', () {
    late MethodChannel methodChannel;
    late AudioServiceImpl service;
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      methodChannel = const MethodChannel('com.yap.audio');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        log.add(call);
        switch (call.method) {
          case 'hasPermission':
            return true;
          case 'requestPermission':
            return true;
          default:
            return null;
        }
      });

      service = AudioServiceImpl(
        methodChannel: methodChannel,
      );
    });

    test('startCapture sends startCapture method', () async {
      await service.startCapture();

      expect(log, hasLength(1));
      expect(log.first.method, 'startCapture');
      expect(service.isCapturing, isTrue);
    });

    test('stopCapture sends stopCapture method', () async {
      await service.startCapture();
      await service.stopCapture();

      expect(log.last.method, 'stopCapture');
      expect(service.isCapturing, isFalse);
    });

    test('hasPermission returns result from platform', () async {
      final result = await service.hasPermission();
      expect(result, isTrue);
    });

    test('requestPermission returns result from platform', () async {
      final result = await service.requestPermission();
      expect(result, isTrue);
    });

    test('audioStream returns a broadcast stream', () {
      final stream = service.audioStream;
      expect(stream.isBroadcast, isTrue);
    });

    test('isCapturing is initially false', () {
      expect(service.isCapturing, isFalse);
    });
  });

  group('MockAudioService', () {
    late MockAudioService mock;

    setUp(() {
      mock = MockAudioService();
    });

    tearDown(() {
      mock.dispose();
    });

    test('startCapture sets isCapturing', () async {
      await mock.startCapture();
      expect(mock.isCapturing, isTrue);
    });

    test('stopCapture clears isCapturing', () async {
      await mock.startCapture();
      await mock.stopCapture();
      expect(mock.isCapturing, isFalse);
    });

    test('startCapture throws when permission not granted', () async {
      mock.permissionGranted = false;
      expect(mock.startCapture(), throwsException);
    });

    test('pushAudioChunk emits on audioStream', () async {
      final completer = Completer<Uint8List>();
      mock.audioStream.listen((data) => completer.complete(data));

      final chunk = Uint8List.fromList([1, 2, 3, 4]);
      mock.pushAudioChunk(chunk);

      final received = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(received, equals(chunk));
    });

    test('hasPermission reflects permissionGranted setter', () async {
      expect(await mock.hasPermission(), isTrue);
      mock.permissionGranted = false;
      expect(await mock.hasPermission(), isFalse);
    });
  });
}
