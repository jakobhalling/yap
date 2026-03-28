import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/recording/recording_providers.dart';
import 'package:yap/features/tray/tray_service.dart';

/// Provider for the system tray service.
///
/// Depends on [recordingServiceProvider] from Agent 2 so that the tray menu
/// can toggle recording.
final trayServiceProvider = Provider<TrayService>((ref) {
  final recordingService = ref.watch(recordingServiceProvider);
  final tray = TrayService(recordingService: recordingService);
  ref.onDispose(() => tray.dispose());
  return tray;
});
