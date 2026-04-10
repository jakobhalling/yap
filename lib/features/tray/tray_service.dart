import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:yap/features/recording/recording_service.dart';
import 'package:yap/utils/constants.dart';

/// Manages the system-tray icon and context menu.
///
/// Menu items wire into recording toggle, settings, history, about, and quit.
class TrayService {
  final RecordingService recordingService;

  /// Callbacks wired by the app layer to open settings / history windows.
  VoidCallback? onOpenSettings;
  VoidCallback? onOpenHistory;
  VoidCallback? onToggleRecording;

  TrayService({required this.recordingService});

  final SystemTray _tray = SystemTray();
  bool _isRecording = false;
  Brightness _currentBrightness = PlatformDispatcher.instance.platformBrightness;

  /// Returns the icon path for the current platform, recording state, and theme.
  ///
  /// On macOS, uses the light (black) variant as a template image —
  /// macOS automatically tints it white in dark mode and black in light mode.
  /// On Windows, manually selects dark/light variant based on system theme.
  String _iconPath({required bool recording}) {
    final state = recording ? 'tray_icon_recording' : 'tray_icon';
    if (Platform.isMacOS) {
      return 'assets/icons/${state}_light.png';
    }
    final isDark = _currentBrightness == Brightness.dark;
    final variant = isDark ? 'dark' : 'light';
    return 'assets/icons/${state}_$variant.ico';
  }

  /// Initialize the tray icon and context menu. Call once at app startup.
  Future<void> init() async {
    await _tray.initSystemTray(
      title: Platform.isMacOS ? '' : 'Yap',
      iconPath: _iconPath(recording: false),
      toolTip: 'Yap — voice to text',
      isTemplate: Platform.isMacOS,
    );

    await _buildMenu();

    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick ||
          eventName == kSystemTrayEventRightClick) {
        _tray.popUpContextMenu();
      }
    });

    // Listen for system theme changes and update icon accordingly.
    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      final newBrightness = PlatformDispatcher.instance.platformBrightness;
      if (newBrightness != _currentBrightness) {
        _currentBrightness = newBrightness;
        _updateIcon();
      }
    };
  }

  /// Rebuild the context menu (e.g., after recording state changes).
  Future<void> _buildMenu() async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Yap',
        enabled: false,
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: _isRecording ? 'Stop Recording' : 'Start Recording',
        onClicked: (_) => onToggleRecording?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'History',
        onClicked: (_) => onOpenHistory?.call(),
      ),
      MenuItemLabel(
        label: 'Settings',
        onClicked: (_) => onOpenSettings?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'About',
        onClicked: (_) => _showAbout(),
      ),
      MenuItemLabel(
        label: 'Quit',
        onClicked: (_) => _quit(),
      ),
    ]);
    await _tray.setContextMenu(menu);
  }

  /// Update the tray to reflect current recording state.
  Future<void> setRecording(bool isRecording) async {
    if (_isRecording == isRecording) return;
    _isRecording = isRecording;
    await _buildMenu();
    await _updateIcon();
  }

  /// Update the tray icon based on current recording state and system theme.
  Future<void> _updateIcon() async {
    try {
      await _tray.setImage(
        _iconPath(recording: _isRecording),
        isTemplate: Platform.isMacOS,
      );
    } catch (_) {}
  }

  void _showAbout() {
    // Simple about dialog — in a real app this would use a proper dialog
    // shown from the overlay or main window context.
    debugPrint('Yap v$appVersion — Voice-driven text input');
  }

  Future<void> _quit() async {
    await windowManager.destroy();
  }

  void dispose() {
    _tray.destroy();
  }
}
