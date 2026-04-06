import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:yap/features/overlay/overlay_controller.dart';
import 'package:yap/features/overlay/widgets/waveform_animation.dart';

// ─── Typography ──────────────────────────────────────────────────────────────

TextStyle _font(double size, {FontWeight weight = FontWeight.w300, Color color = Colors.white}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0.2,
    height: 1.4,
  );
}

TextStyle _mono(double size, {Color color = Colors.white70}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.5,
  );
}

// ─── Overlay Screen ──────────────────────────────────────────────────────────

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
    if (prev == OverlayPhase.hidden && s.phase == OverlayPhase.recording) {
      _playSound('assets/sounds/record_start.wav');
    } else if (prev == OverlayPhase.recording && s.phase != OverlayPhase.recording) {
      _playSound('assets/sounds/record_stop.wav');
    }
    if (mounted) {
      setState(() => _state = s);
      if (s.phase != OverlayPhase.hidden) _focusNode.requestFocus();
    }
  }

  Future<void> _playSound(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch (_) {}
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
    _ctrl.handleKey(event.logicalKey, isAltPressed: event.isAltPressed);
  }

  void _onSizeChanged(Size size) {
    // Add a small buffer for the window chrome/shadow.
    _ctrl.overlayWindow.updateSize(size.height + 16);
  }

  @override
  Widget build(BuildContext context) {
    if (_state.phase == OverlayPhase.hidden) return const SizedBox.shrink();

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _onKey,
      child: Material(
        color: Colors.transparent,
        child: _MeasureSize(
          onChange: _onSizeChanged,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state.phase) {
      case OverlayPhase.hidden:
        return const SizedBox.shrink();
      case OverlayPhase.recording:
        return _recordingView();
      case OverlayPhase.transcriptComplete:
        return _transcriptCompleteView();
      case OverlayPhase.processing:
        return _processingView();
      case OverlayPhase.readyToPaste:
        return _readyToPasteView();
      case OverlayPhase.copied:
        return _copiedView();
      case OverlayPhase.error:
        return _errorView();
    }
  }

  // ─── Recording ─────────────────────────────────────────────────────────────

  Widget _recordingView() {
    final t = _state.transcript;
    final display = t.length > 120 ? t.substring(t.length - 120) : t;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaveformAnimation(audioLevel: _state.audioLevel),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: Text(
              display.isEmpty ? '' : display,
              style: _mono(9, color: Colors.white.withValues(alpha: 0.9)),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transcript Complete ───────────────────────────────────────────────────

  Widget _transcriptCompleteView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'ready',
                style: _font(11, weight: FontWeight.w500, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Text(
                '${_state.transcript.length} chars · ${_state.elapsed.inSeconds}s',
                style: _mono(9, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Transcript preview
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(
                _state.transcript,
                style: _font(12, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Actions
          _divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _key('↵', 'paste raw'),
              const SizedBox(width: 12),
              ..._state.profiles
                  .where((p) => !p.isEmpty)
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _key('${p.slot}', p.name.toLowerCase()),
                      )),
              const Spacer(),
              _copyButton(),
              const SizedBox(width: 12),
              _key('esc', 'cancel', muted: true),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Processing ────────────────────────────────────────────────────────────

  Widget _processingView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with spinner
          Row(
            children: [
              _spinner(),
              const SizedBox(width: 8),
              Text(
                _state.profileName?.toLowerCase() ?? 'processing',
                style: _font(11, weight: FontWeight.w500, color: Colors.white70),
              ),
              const Spacer(),
              Text(
                '${_state.processedText.length} chars',
                style: _mono(9, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Streaming output
          if (_state.processedText.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _state.processedText,
                  style: _font(12, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            )
          else
            Text(
              'waiting for response...',
              style: _font(11, color: Colors.white54),
            ),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 8),
          _key('esc', 'cancel', muted: true),
        ],
      ),
    );
  }

  // ─── Ready to Paste ────────────────────────────────────────────────────────

  Widget _readyToPasteView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'done',
                style: _font(11, weight: FontWeight.w500, color: const Color(0xFF4ADE80)),
              ),
              const SizedBox(width: 8),
              Text(
                '${_state.processedText.length} chars',
                style: _mono(9, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Result
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                _state.processedText,
                style: _font(12, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _key('↵', 'paste'),
              const Spacer(),
              _copyButton(),
              const SizedBox(width: 12),
              _key('esc', 'cancel', muted: true),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Copied ────────────────────────────────────────────────────────────────

  Widget _copiedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF4ADE80), size: 16),
          const SizedBox(width: 8),
          Text(
            'copied to clipboard',
            style: _font(12, weight: FontWeight.w400, color: const Color(0xFF4ADE80)),
          ),
        ],
      ),
    );
  }

  // ─── Error ─────────────────────────────────────────────────────────────────

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'error',
                style: _font(11, weight: FontWeight.w500, color: const Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            _state.errorMessage ?? 'Something went wrong',
            style: _mono(10, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
            maxLines: 4,
          ),
          if (_state.transcript.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_state.transcript.length} chars captured',
              style: _mono(9, color: Colors.white54),
            ),
          ],
          const SizedBox(height: 14),
          _divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_state.transcript.isNotEmpty)
                _key('↵', 'paste raw'),
              const Spacer(),
              _key('esc', 'dismiss', muted: true),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared components ─────────────────────────────────────────────────────

  Widget _key(String k, String label, {bool muted = false}) {
    final keyColor = muted ? Colors.white38 : Colors.white70;
    final labelColor = muted ? Colors.white38 : Colors.white60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: keyColor.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(k, style: _mono(9, color: keyColor)),
        ),
        const SizedBox(width: 5),
        Text(label, style: _font(10, color: labelColor)),
      ],
    );
  }

  Widget _copyButton() {
    return Tooltip(
      message: 'Copy to clipboard (Alt+C)',
      child: InkWell(
        onTap: () => _ctrl.copyCurrentAndClose(),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.content_copy_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text('alt+c', style: _mono(8, color: Colors.white.withValues(alpha: 0.55))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _spinner() {
    return SizedBox(
      width: 10,
      height: 10,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─── Size measurement widget ────────────────────────────────────────────────

class _MeasureSize extends StatefulWidget {
  final ValueChanged<Size> onChange;
  final Widget child;

  const _MeasureSize({required this.onChange, required this.child});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();
  Size _oldSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSize());
  }

  @override
  void didUpdateWidget(_MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSize());
  }

  void _checkSize() {
    final context = _key.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final newSize = box.size;
    if (newSize != _oldSize) {
      _oldSize = newSize;
      widget.onChange(newSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: _key, child: widget.child);
  }
}
