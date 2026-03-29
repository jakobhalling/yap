import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that lets the user press a modifier key to set it as the
/// double-tap trigger. Shows the current key and enters "recording" mode
/// on click, capturing the next modifier key press.
class HotkeyRecorder extends StatefulWidget {
  final String currentKey;
  final ValueChanged<String> onKeyChanged;

  const HotkeyRecorder({
    super.key,
    required this.currentKey,
    required this.onKeyChanged,
  });

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  bool _recording = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() => _recording = true);
    _focusNode.requestFocus();
  }

  void _cancelRecording() {
    setState(() => _recording = false);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_recording) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      // Escape cancels recording
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelRecording();
        return KeyEventResult.handled;
      }

      // Check if it's a modifier key we support
      final keyId = _physicalKeyToId(event.physicalKey);
      if (keyId != null) {
        widget.onKeyChanged(keyId);
        setState(() => _recording = false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  String? _physicalKeyToId(PhysicalKeyboardKey key) {
    // Map physical keys to our trigger key identifiers
    if (key == PhysicalKeyboardKey.metaLeft) return 'left_command';
    if (key == PhysicalKeyboardKey.metaRight) return 'right_command';
    if (key == PhysicalKeyboardKey.altLeft) return 'left_option';
    if (key == PhysicalKeyboardKey.altRight) return 'right_option';
    if (key == PhysicalKeyboardKey.controlLeft) return 'left_control';
    if (key == PhysicalKeyboardKey.controlRight) return 'right_control';
    if (key == PhysicalKeyboardKey.shiftLeft) return 'left_shift';
    if (key == PhysicalKeyboardKey.shiftRight) return 'right_shift';
    if (key == PhysicalKeyboardKey.fn) return 'fn';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: _recording ? _cancelRecording : _startRecording,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _recording
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _recording
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.5),
              width: _recording ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _recording ? Icons.keyboard : Icons.keyboard_alt_outlined,
                size: 20,
                color: _recording
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _recording
                    ? Text(
                        'Press a modifier key...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Text(
                        displayName(widget.currentKey),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              if (!_recording)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Double-tap',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (_recording)
                Text(
                  'Esc to cancel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Human-readable name for a trigger key identifier.
  static String displayName(String keyId) {
    final isMac = Platform.isMacOS;
    switch (keyId) {
      case 'left_command':
        return isMac ? 'Left Command (\u2318)' : 'Left Win';
      case 'right_command':
        return isMac ? 'Right Command (\u2318)' : 'Right Win';
      case 'left_option':
      case 'left_alt':
        return isMac ? 'Left Option (\u2325)' : 'Left Alt';
      case 'right_option':
      case 'right_alt':
        return isMac ? 'Right Option (\u2325)' : 'Right Alt';
      case 'left_control':
        return isMac ? 'Left Control (\u2303)' : 'Left Ctrl';
      case 'right_control':
        return isMac ? 'Right Control (\u2303)' : 'Right Ctrl';
      case 'left_shift':
        return isMac ? 'Left Shift (\u21E7)' : 'Left Shift';
      case 'right_shift':
        return isMac ? 'Right Shift (\u21E7)' : 'Right Shift';
      case 'fn':
        return 'Fn';
      default:
        return keyId;
    }
  }
}
