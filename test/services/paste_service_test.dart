import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yap/services/paste/paste_service_impl.dart';
import 'package:yap/services/paste/mock_paste_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PasteServiceImpl', () {
    late MethodChannel methodChannel;
    late PasteServiceImpl service;
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      methodChannel = const MethodChannel('com.yap.paste');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        log.add(call);
        return true;
      });

      service = PasteServiceImpl(
        methodChannel: methodChannel,
      );
    });

    test('pasteText sends paste method with text', () async {
      await service.pasteText('Hello, world!');

      expect(log, hasLength(1));
      expect(log.first.method, 'paste');
      expect(log.first.arguments, {'text': 'Hello, world!'});
    });

    test('pasteText returns true on success', () async {
      final result = await service.pasteText('test');
      expect(result, isTrue);
    });

    test('pasteText returns false when platform returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        return false;
      });

      final result = await service.pasteText('test');
      expect(result, isFalse);
    });

    test('pasteText handles empty string', () async {
      await service.pasteText('');
      expect(log.first.arguments, {'text': ''});
    });

    test('pasteText handles special characters', () async {
      await service.pasteText('Line1\nLine2\tTabbed "quoted"');
      expect(log.first.arguments, {'text': 'Line1\nLine2\tTabbed "quoted"'});
    });
  });

  group('MockPasteService', () {
    late MockPasteService mock;

    setUp(() {
      mock = MockPasteService();
    });

    test('pasteText records calls', () async {
      await mock.pasteText('Hello');
      await mock.pasteText('World');

      expect(mock.pastedTexts, ['Hello', 'World']);
    });

    test('pasteText returns true by default', () async {
      final result = await mock.pasteText('test');
      expect(result, isTrue);
    });

    test('pasteText returns false when shouldSucceed is false', () async {
      mock.shouldSucceed = false;
      final result = await mock.pasteText('test');
      expect(result, isFalse);
    });
  });
}
