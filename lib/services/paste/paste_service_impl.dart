import 'package:flutter/services.dart';

import 'paste_service.dart';

/// Platform-channel backed implementation of [PasteService].
///
/// The native side handles the full clipboard save → set text →
/// simulate keypress → restore clipboard flow.
class PasteServiceImpl implements PasteService {
  PasteServiceImpl({
    MethodChannel? methodChannel,
  }) : _methodChannel =
            methodChannel ?? const MethodChannel('com.yap.paste');

  final MethodChannel _methodChannel;

  @override
  Future<bool> pasteText(String text) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'paste',
      <String, dynamic>{'text': text},
    );
    return result ?? false;
  }
}
