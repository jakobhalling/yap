import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

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
import 'features/setup/setup_screen.dart';
import 'services/providers.dart';
import 'shared/theme/app_theme.dart';
import 'utils/constants.dart';

enum AppMode { loading, setup, tray }

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  AppMode _mode = AppMode.loading;
  OverlayController? _overlayController;
  TrayService? _trayService;
  late final OverlayWindow _overlayWindow;

  // Track which secondary view is open so we can show/hide window
  _SecondaryView? _secondaryView;

  @override
  void initState() {
    super.initState();
    _overlayWindow = OverlayWindow();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstBoot());
  }

  Future<void> _checkFirstBoot() async {
    final settings = ref.read(settingsServiceProvider);
    final setupDone = await settings.isSetupComplete();

    if (!setupDone) {
      // Show setup wizard in a visible, centered window
      await windowManager.setSize(const Size(580, 520));
      await windowManager.center();
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setTitle('Yap Setup');
      await windowManager.setSkipTaskbar(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.show();
      await windowManager.focus();
      setState(() => _mode = AppMode.setup);
    } else {
      _enterTrayMode();
    }
  }

  Future<void> _enterTrayMode() async {
    // Hide the window — app lives in the tray
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);

    await _initServices();
    setState(() => _mode = AppMode.tray);
  }

  Future<void> _initServices() async {
    final hotkeyService = ref.read(hotkeyServiceProvider);
    final pasteService = ref.read(pasteServiceProvider);
    final audioService = ref.read(audioServiceProvider);
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
      audioService: audioService,
      profileDao: profileDao,
    );
    _overlayController!.initialize();

    // Load saved trigger key before starting hotkey monitoring
    final triggerKey = await settingsService.getTriggerKey();
    await _startHotkeyWithRetry(hotkeyService, triggerKey);

    _trayService = TrayService(recordingService: recordingService);
    _trayService!.onToggleRecording = () {
      _overlayController!.handleTrayToggle();
    };
    _trayService!.onOpenSettings = () => _openSecondary(_SecondaryView.settings);
    _trayService!.onOpenHistory = () => _openSecondary(_SecondaryView.history);
    _trayService!.init();

    _overlayController!.stateStream.listen((state) {
      _trayService!.setRecording(state.phase == OverlayPhase.recording);
    });

    // Check for updates in background after startup.
    final updateService = ref.read(updateServiceProvider);
    updateService.checkForUpdate(appVersion);
  }

  /// Starts hotkey monitoring, retrying if accessibility permission is pending.
  /// On macOS the user may have just granted permission in System Settings;
  /// TCC can take a moment to propagate.
  Future<void> _startHotkeyWithRetry(
    dynamic hotkeyService,
    String? triggerKey,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await hotkeyService.start(triggerKey: triggerKey);
        return; // success
      } catch (e) {
        debugPrint('[Yap] Hotkey start attempt ${attempt + 1} failed: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    debugPrint(
      '[Yap] Hotkey start failed after retries. '
      'Check Accessibility permission in System Settings.',
    );
  }

  /// Open settings or history in the main window (temporarily visible).
  Future<void> _openSecondary(_SecondaryView view) async {
    setState(() => _secondaryView = view);
    await windowManager.setSize(const Size(640, 520));
    await windowManager.center();
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setTitle(
        view == _SecondaryView.settings ? 'Yap Settings' : 'Yap History');
    await windowManager.setSkipTaskbar(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _closeSecondary() async {
    setState(() => _secondaryView = null);
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
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
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_mode) {
      case AppMode.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case AppMode.setup:
        return SetupScreen(onComplete: _enterTrayMode);

      case AppMode.tray:
        // If a secondary view is open, show it
        if (_secondaryView != null) {
          return _buildSecondaryView();
        }
        // Otherwise show the overlay (window is hidden, but overlay_screen
        // handles show/hide via OverlayWindow)
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: _overlayController != null
              ? OverlayScreen(controller: _overlayController!)
              : const SizedBox.shrink(),
        );
    }
  }

  Widget _buildSecondaryView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _secondaryView == _SecondaryView.settings ? 'Settings' : 'History',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: _closeSecondary,
        ),
      ),
      body: _secondaryView == _SecondaryView.settings
          ? const SettingsScreen()
          : const HistoryScreen(),
    );
  }
}

enum _SecondaryView { settings, history }
