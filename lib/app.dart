import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/overlay/overlay_controller.dart';
import 'features/overlay/overlay_screen.dart';
import 'features/overlay/overlay_window.dart';
import 'features/tray/tray_service.dart';
import 'features/history/history_providers.dart';
import 'features/history/history_screen.dart';
import 'features/processing/processing_providers.dart';
import 'features/recording/recording_providers.dart';
import 'features/settings/settings_providers.dart';
import 'features/settings/settings_screen.dart';
import 'services/providers.dart';
import 'shared/theme/app_theme.dart';

/// Root widget for the Yap application.
///
/// The app has no visible main window — it is a system-tray app that shows
/// a floating overlay when the user triggers recording via global hotkey.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  OverlayController? _overlayController;
  TrayService? _trayService;
  late final OverlayWindow _overlayWindow;

  @override
  void initState() {
    super.initState();
    _overlayWindow = OverlayWindow();
    // Defer initialization to after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initServices());
  }

  void _initServices() {
    final hotkeyService = ref.read(hotkeyServiceProvider);
    final pasteService = ref.read(pasteServiceProvider);
    final recordingService = ref.read(recordingServiceProvider);
    final processingService = ref.read(processingServiceProvider);
    final historyService = ref.read(historyServiceProvider);
    final settingsService = ref.read(settingsServiceProvider);
    final profileDao = ref.read(promptProfileDaoProvider);

    _overlayController = OverlayController(
      recordingService: recordingService,
      processingService: processingService,
      pasteService: pasteService,
      historyService: historyService,
      hotkeyService: hotkeyService,
      overlayWindow: _overlayWindow,
      settingsService: settingsService,
      profileDao: profileDao,
    );
    _overlayController!.initialize();

    // Start the global hotkey listener.
    hotkeyService.start();

    // Set up system tray.
    _trayService = TrayService(recordingService: recordingService);
    _trayService!.onToggleRecording = () {
      // Simulate a double-tap from the tray menu
      _overlayController!.handleTrayToggle();
    };
    _trayService!.onOpenSettings = _openSettings;
    _trayService!.onOpenHistory = _openHistory;
    _trayService!.init();

    // Sync tray icon with recording state.
    _overlayController!.stateStream.listen((state) {
      _trayService!.setRecording(state.phase == OverlayPhase.recording);
    });

    setState(() {}); // Trigger rebuild with controller ready.
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 600,
          height: 500,
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  void _openHistory() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 700,
          height: 500,
          child: const HistoryScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayController?.dispose();
    _trayService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _overlayController != null
            ? OverlayScreen(controller: _overlayController!)
            : const SizedBox.shrink(),
      ),
    );
  }
}
