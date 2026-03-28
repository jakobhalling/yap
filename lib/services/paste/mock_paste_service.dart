import 'paste_service.dart';

/// Mock implementation of [PasteService] for use in tests.
///
/// Records calls to [pasteText] so they can be verified in tests.
class MockPasteService implements PasteService {
  final List<String> pastedTexts = [];
  bool shouldSucceed = true;

  @override
  Future<bool> pasteText(String text) async {
    pastedTexts.add(text);
    return shouldSucceed;
  }
}
