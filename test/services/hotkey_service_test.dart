import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/hotkey/hotkey_service_impl.dart';
import 'package:yap/services/hotkey/mock_hotkey_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HotkeyServiceImpl', () {
    late MethodChannel methodChannel;
    late HotkeyServiceImpl service;
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      methodChannel = const MethodChannel('com.yap.hotkey');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        log.add(call);
        return null;
      });

      service = HotkeyServiceImpl(
        methodChannel: methodChannel,
      );
    });

    test('start sends start method with default threshold', () async {
      await service.start();

      expect(log, hasLength(1));
      expect(log.first.method, 'start');
      expect(log.first.arguments, {'threshold': 400});
    });

    test('stop sends stop method', () async {
      await service.stop();

      expect(log, hasLength(1));
      expect(log.first.method, 'stop');
    });

    test('setDoubleTapThreshold sends setThreshold method', () async {
      await service.setDoubleTapThreshold(300);

      expect(log, hasLength(1));
      expect(log.first.method, 'setThreshold');
      expect(log.first.arguments, {'threshold': 300});
    });

    test('setDoubleTapThreshold asserts on out-of-range values', () {
      expect(
        () => service.setDoubleTapThreshold(100),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => service.setDoubleTapThreshold(700),
        throwsA(isA<AssertionError>()),
      );
    });

    test('setDoubleTapThreshold accepts boundary values', () async {
      await service.setDoubleTapThreshold(200);
      await service.setDoubleTapThreshold(600);

      expect(log, hasLength(2));
    });

    test('onDoubleTap returns a broadcast stream', () {
      final stream = service.onDoubleTap;
      expect(stream.isBroadcast, isTrue);
    });
  });

  group('MockHotkeyService', () {
    late MockHotkeyService mock;

    setUp(() {
      mock = MockHotkeyService();
    });

    tearDown(() {
      mock.dispose();
    });

    test('start sets isStarted', () async {
      expect(mock.isStarted, isFalse);
      await mock.start();
      expect(mock.isStarted, isTrue);
    });

    test('stop clears isStarted', () async {
      await mock.start();
      await mock.stop();
      expect(mock.isStarted, isFalse);
    });

    test('simulateDoubleTap emits on onDoubleTap stream', () async {
      final completer = Completer<void>();
      mock.onDoubleTap.listen((_) => completer.complete());

      mock.simulateDoubleTap();

      await completer.future.timeout(const Duration(seconds: 1));
    });

    test('setDoubleTapThreshold updates threshold', () async {
      await mock.setDoubleTapThreshold(250);
      expect(mock.threshold, 250);
    });

    test('setDoubleTapThreshold asserts on invalid range', () {
      expect(
        () => mock.setDoubleTapThreshold(100),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
