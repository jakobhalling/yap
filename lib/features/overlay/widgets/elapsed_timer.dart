import 'package:flutter/material.dart';

/// Displays a recording duration formatted as "0:05", "1:23", etc.
class ElapsedTimerWidget extends StatelessWidget {
  final Duration elapsed;

  const ElapsedTimerWidget({super.key, required this.elapsed});

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(elapsed),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
