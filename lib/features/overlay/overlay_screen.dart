import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:yap/features/overlay/overlay_controller.dart';
import 'package:yap/features/overlay/widgets/elapsed_timer.dart';
import 'package:yap/features/overlay/widgets/processing_indicator.dart';
import 'package:yap/features/overlay/widgets/profile_selector.dart';
import 'package:yap/features/overlay/widgets/transcript_view.dart';
import 'package:yap/features/overlay/widgets/waveform_animation.dart';
import 'package:yap/shared/theme/app_theme.dart';

/// The widget rendered inside the overlay window.
///
/// Listens to [OverlayController.stateStream] and switches between recording,
/// transcript complete, processing, ready-to-paste, and error views.
class OverlayScreen extends ConsumerStatefulWidget {
  final OverlayController controller;

  const OverlayScreen({super.key, required this.controller});

  @override
  ConsumerState<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends ConsumerState<OverlayScreen> {
  late final FocusNode _focusNode;
  late final StreamSubscription<YapOverlayState> _sub;
  YapOverlayState _state = const YapOverlayState();
  final AudioPlayer _audioPlayer = AudioPlayer();
  OverlayPhase? _previousPhase;

  OverlayController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _state = _ctrl.state;
    _sub = _ctrl.stateStream.listen(_onStateChange);
  }

  void _onStateChange(YapOverlayState s) {
    final prev = _previousPhase;
    _previousPhase = s.phase;

    // Play sound cues on state transitions.
    if (prev == OverlayPhase.hidden && s.phase == OverlayPhase.recording) {
      _playSound('assets/sounds/record_start.wav');
    } else if (prev == OverlayPhase.recording &&
        s.phase != OverlayPhase.recording) {
      _playSound('assets/sounds/record_stop.wav');
    }

    if (mounted) {
      setState(() => _state = s);
      // Ensure keyboard focus when overlay is visible.
      if (s.phase != OverlayPhase.hidden) {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _playSound(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch (_) {
      // Non-critical.
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    _ctrl.handleKey(event.logicalKey);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.overlayBackgroundDark : AppTheme.overlayBackgroundLight;

    if (_state.phase == OverlayPhase.hidden) {
      return const SizedBox.shrink();
    }

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _onKey,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state.phase) {
      case OverlayPhase.hidden:
        return const SizedBox.shrink();

      case OverlayPhase.recording:
        return _recordingView(context);

      case OverlayPhase.transcriptComplete:
        return _transcriptCompleteView(context);

      case OverlayPhase.processing:
        return _processingView(context);

      case OverlayPhase.readyToPaste:
        return _readyToPasteView(context);

      case OverlayPhase.error:
        return _errorView(context);
    }
  }

  Widget _recordingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Recording',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              ElapsedTimerWidget(elapsed: _state.elapsed),
            ],
          ),
          const SizedBox(height: 12),
          const WaveformAnimation(),
          const SizedBox(height: 12),
          if (_state.transcript.isNotEmpty)
            Flexible(
              child: TranscriptView(
                text: _state.transcript,
                isStreaming: true,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Double-tap to stop recording',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _transcriptCompleteView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcript ready',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              ElapsedTimerWidget(elapsed: _state.elapsed),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: TranscriptView(
              text: _state.transcript,
              isStreaming: false,
            ),
          ),
          const SizedBox(height: 12),
          ProfileSelector(
            profiles: _state.profiles,
            selectedSlot: null,
          ),
        ],
      ),
    );
  }

  Widget _processingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProcessingIndicator(
            profileName: _state.profileName ?? 'Profile',
            streamingText: _state.processedText,
            isComplete: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Esc to cancel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _readyToPasteView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProcessingIndicator(
            profileName: _state.profileName ?? 'Profile',
            streamingText: _state.processedText,
            isComplete: true,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _keyHint(context, 'Enter', 'Paste'),
              const SizedBox(width: 24),
              _keyHint(context, 'Esc', 'Cancel'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _state.errorMessage ?? 'An error occurred',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_state.transcript.isNotEmpty)
                _keyHint(context, 'Enter', 'Paste raw transcript'),
              if (_state.transcript.isNotEmpty) const SizedBox(width: 24),
              _keyHint(context, 'Esc', 'Dismiss'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyHint(BuildContext context, String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
