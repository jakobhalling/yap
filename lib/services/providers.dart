import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_service.dart';
import 'audio/audio_service_impl.dart';
import 'hotkey/hotkey_service.dart';
import 'hotkey/hotkey_service_impl.dart';
import 'paste/paste_service.dart';
import 'paste/paste_service_impl.dart';
import 'update_service.dart';

/// Provider for the global hotkey detection service.
final hotkeyServiceProvider = Provider<HotkeyService>((ref) {
  final service = HotkeyServiceImpl();
  ref.onDispose(() => service.stop());
  return service;
});

/// Provider for the audio capture service.
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioServiceImpl();
});

/// Provider for the paste simulation service.
final pasteServiceProvider = Provider<PasteService>((ref) {
  return PasteServiceImpl();
});

/// Provider for the auto-update service.
final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(() => service.dispose());
  return service;
});
