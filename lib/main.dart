import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Log.init();
  Log.i('App', 'Starting Yap v$appVersion');

  // Initialize window manager for tray-only frameless app.
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(600, 400),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Start hidden — the app lives in the system tray and shows an overlay
    // only when activated via the global hotkey.
    await windowManager.hide();
  });

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
