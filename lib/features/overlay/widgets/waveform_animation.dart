import 'dart:math';

import 'package:flutter/material.dart';

/// Animated vertical bars that pulse to indicate recording is in progress.
///
/// Not driven by actual audio levels — purely decorative. 6 bars animate at
/// different frequencies and phases for an organic feel.
class WaveformAnimation extends StatefulWidget {
  const WaveformAnimation({super.key});

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _barCount = 6;
  // Each bar has a unique speed multiplier and phase offset.
  static const List<double> _speeds = [1.0, 1.4, 0.9, 1.6, 1.1, 1.3];
  static const List<double> _phases = [0, 0.5, 1.1, 0.3, 1.7, 0.8];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
      height: 32,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_barCount, (i) {
              final t = _controller.value * 2 * pi * _speeds[i] + _phases[i];
              // Map sin to [0.15, 1.0] so bars never fully disappear.
              final normalized = (sin(t) + 1) / 2 * 0.85 + 0.15;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Bar(heightFraction: normalized),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double heightFraction;
  const _Bar({required this.heightFraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 28 * heightFraction,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
