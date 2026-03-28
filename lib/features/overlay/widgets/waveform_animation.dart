import 'dart:math';

import 'package:flutter/material.dart';

/// Full-width waveform visualization driven by real microphone audio level.
/// White bars on black background.
class WaveformAnimation extends StatefulWidget {
  final double audioLevel;

  const WaveformAnimation({super.key, this.audioLevel = 0.0});

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _barCount = 40;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final level = widget.audioLevel.clamp(0.0, 1.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (i) {
              // Create a wave pattern centered on the middle bars
              final center = _barCount / 2;
              final distFromCenter = (i - center).abs() / center;

              // Phase varies by position for wave effect
              final phase = i * 0.3 + _controller.value * 2 * pi;
              final wave = sin(phase) * 0.5 + 0.5;

              double height;
              if (level < 0.01) {
                // Idle: very subtle center pulse
                height = 0.03 + (1 - distFromCenter) * 0.04 * wave;
              } else {
                // Active: bars respond to level, taller in center
                final envelope = 1.0 - distFromCenter * 0.6;
                height = (level * envelope * (0.5 + wave * 0.5))
                    .clamp(0.02, 1.0);
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.5),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      height: 44 * height,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: level < 0.01 ? 0.2 : 0.7 + height * 0.3,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
