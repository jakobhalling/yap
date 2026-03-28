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

    _initServices();
    setState(() => _mode = AppMode.tray);
  }

  void _initServices() {
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

    hotkeyService.start();

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
