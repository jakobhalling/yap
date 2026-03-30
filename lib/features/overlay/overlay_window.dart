import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Manages the overlay window — positioning, sizing, show/hide animations.
///
/// Uses the single application window via [window_manager]. The window is kept
/// alive and simply shown/hidden as needed.
class OverlayWindow {
  static const double _overlayWidth = 600;
  static const double _minHeight = 120;
  static const double _maxHeightFraction = 0.6;

  bool _isVisible = false;
  bool get isVisible => _isVisible;

  double _currentHeight = _minHeight;

  /// Show the overlay at top-center of the primary screen.
  Future<void> show() async {
    if (_isVisible) return;

    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.size;

    final left = (screenSize.width - _overlayWidth) / 2;
    const top = 40.0; // slight offset from top edge

    _currentHeight = _minHeight;

    // Configure window properties before showing.
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAsFrameless();
    await windowManager.setSkipTaskbar(true);
    await windowManager.setOpacity(1.0);
    await windowManager.setPosition(Offset(left, top));
    await windowManager.setSize(Size(_overlayWidth, _currentHeight));

    // Show first, then force always-on-top and focus.
    // On macOS, tray-only apps need show → alwaysOnTop → focus in this order
    // to reliably appear above other windows.
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();
    // Re-focus after a short delay to handle macOS activation quirks.
    await Future.delayed(const Duration(milliseconds: 50));
    await windowManager.focus();

    _isVisible = true;
  }

  /// Hide the overlay with a quick fade.
  Future<void> hide() async {
    if (!_isVisible) return;

    // Quick fade-out (100ms)
    await windowManager.setOpacity(0.0);
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.hide();
    await windowManager.setOpacity(1.0);
    _isVisible = false;
  }

  /// Resize the overlay height (grows downward from top).
  Future<void> updateSize(double height) async {
    if (!_isVisible) return;

    final display = await screenRetriever.getPrimaryDisplay();
    final maxHeight = display.size.height * _maxHeightFraction;
    final clampedHeight = height.clamp(_minHeight, maxHeight);

    if ((clampedHeight - _currentHeight).abs() < 2) return; // skip tiny changes
    _currentHeight = clampedHeight;
    await windowManager.setSize(Size(_overlayWidth, _currentHeight));
  }
}
