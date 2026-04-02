import 'dart:io';

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

  /// Initialize the tray icon and context menu. Call once at app startup.
  Future<void> init() async {
    final iconPath = Platform.isWindows
        ? 'assets/icons/tray_icon.ico'
        : 'assets/icons/tray_icon.png';

    await _tray.initSystemTray(
      title: 'Yap',
      iconPath: iconPath,
      toolTip: 'Yap — voice to text',
    );

    await _buildMenu();

    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick ||
          eventName == kSystemTrayEventRightClick) {
        _tray.popUpContextMenu();
      }
    });
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

    // Swap tray icon if recording-specific icon exists.
    if (isRecording) {
      final recordingIcon = Platform.isWindows
          ? 'assets/icons/tray_icon_recording.ico'
          : 'assets/icons/tray_icon_recording.png';
      try {
        await _tray.setImage(recordingIcon);
      } catch (_) {
        // Fall back — recording icon might not exist yet.
      }
    } else {
      final idleIcon = Platform.isWindows
          ? 'assets/icons/tray_icon.ico'
          : 'assets/icons/tray_icon.png';
      try {
        await _tray.setImage(idleIcon);
      } catch (_) {}
    }
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
